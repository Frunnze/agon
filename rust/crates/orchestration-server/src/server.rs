mod server_standing;

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, MutexGuard};

use chrono::{DateTime, Utc};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::server_group::ServerStanding;
use orchestration_security::identity::{DeviceIdentity, PublicIdentity};
use orchestration_security::request_signing::RequestSignature;
use tokio::sync::watch;

use crate::account_setup::{SetupCodeClaim, prepare_setup_code};
use crate::audit_log::{AuditEvent, append_audit_event};
use crate::change::{Change, ChangeEffect};
use crate::clock::Clock;
use crate::error::ServerError;
use crate::events::append_notification;
use crate::persistence::StateStorage;
use crate::replica_copies::ReplicaCopyLedger;
use crate::request_ledger::{Presence, RequestLedger};
use crate::settings::ServerSettings;
use crate::setup_code::SetupCode;
use crate::stored_state::StoredState;

pub type SharedServer = Arc<Server>;

const POISONED_STATE: &str = "the server state lock is poisoned";
const POISONED_LEDGER: &str = "the request ledger lock is poisoned";
const POISONED_SETUP_CODE: &str = "the setup code lock is poisoned";

#[derive(Debug)]
pub struct Server {
    state: Mutex<StoredState>,
    request_ledger: Mutex<RequestLedger>,
    replica_copies: Mutex<ReplicaCopyLedger>,
    setup_code: Mutex<Option<SetupCode>>,
    newly_issued_setup_code: Option<String>,
    started_at: DateTime<Utc>,
    identity: DeviceIdentity,
    clock: Arc<dyn Clock>,
    storage: StateStorage,
    settings: ServerSettings,
    latest_sequence: watch::Sender<u64>,
    latest_revision: watch::Sender<u64>,
    accepts_writes: AtomicBool,
}

impl Server {
    pub fn open(
        settings: ServerSettings,
        clock: Arc<dyn Clock>,
    ) -> Result<Self, ServerError> {
        let storage = StateStorage::new(settings.data_directory.clone());
        let identity = storage.load_or_create_identity()?;
        let stored_state = storage.load_state()?;
        let prepared_setup = prepare_setup_code(&storage, &stored_state)?;
        let latest_sequence = watch::Sender::new(stored_state.latest_sequence);
        let latest_revision = watch::Sender::new(stored_state.revision);
        let accepts_writes =
            opens_as_active(&stored_state, &identity.device_id());
        Ok(Self {
            state: Mutex::new(stored_state),
            request_ledger: Mutex::new(RequestLedger::default()),
            replica_copies: Mutex::new(ReplicaCopyLedger::default()),
            setup_code: Mutex::new(prepared_setup.setup_code),
            newly_issued_setup_code: prepared_setup.newly_issued,
            started_at: clock.now(),
            identity,
            clock,
            storage,
            settings,
            latest_sequence,
            latest_revision,
            accepts_writes: AtomicBool::new(accepts_writes),
        })
    }

    #[must_use]
    pub fn now(&self) -> DateTime<Utc> {
        self.clock.now()
    }

    #[must_use]
    pub fn started_at(&self) -> DateTime<Utc> {
        self.started_at
    }

    #[must_use]
    pub fn newly_issued_setup_code(&self) -> Option<&str> {
        self.newly_issued_setup_code.as_deref()
    }

    pub fn claim_setup_code(
        &self,
        offered_text: &str,
    ) -> Result<SetupCodeClaim<'_>, ServerError> {
        let setup_code = self
            .setup_code
            .lock()
            .map_err(|_| ServerError::Internal(POISONED_SETUP_CODE))?;
        SetupCodeClaim::verify(setup_code, &self.storage, offered_text)
    }

    pub fn read_setup_code(&self) -> Result<Option<String>, ServerError> {
        let setup_code = self
            .setup_code
            .lock()
            .map_err(|_| ServerError::Internal(POISONED_SETUP_CODE))?;
        Ok(setup_code.as_ref().map(SetupCode::display))
    }

    #[must_use]
    pub fn device_id(&self) -> DeviceId {
        self.identity.device_id()
    }

    #[must_use]
    pub fn public_identity(&self) -> PublicIdentity {
        self.identity.public_identity()
    }

    #[must_use]
    pub fn settings(&self) -> &ServerSettings {
        &self.settings
    }

    pub fn snapshot_state(&self) -> Result<StoredState, ServerError> {
        let state = self.lock_state()?;
        Ok(state.clone())
    }

    pub fn read<Output>(
        &self,
        reader: impl FnOnce(&StoredState) -> Result<Output, ServerError>,
    ) -> Result<Output, ServerError> {
        let state = self.lock_state()?;
        reader(&state)
    }

    #[must_use]
    pub fn standing(&self) -> ServerStanding {
        if self.accepts_writes.load(Ordering::SeqCst) {
            return ServerStanding::Active;
        }
        ServerStanding::Backup
    }

    pub fn apply<Outcome>(
        &self,
        acting_device: &DeviceId,
        change: impl FnOnce(
            &mut StoredState,
            DateTime<Utc>,
        ) -> Result<Change<Outcome>, ServerError>,
    ) -> Result<Outcome, ServerError> {
        let state = self.lock_state()?;
        if self.standing() == ServerStanding::Backup {
            return Err(ServerError::NotActive);
        }
        self.apply_locked(state, acting_device, change)
    }

    fn apply_locked<Outcome>(
        &self,
        state: MutexGuard<'_, StoredState>,
        acting_device: &DeviceId,
        change: impl FnOnce(
            &mut StoredState,
            DateTime<Utc>,
        ) -> Result<Change<Outcome>, ServerError>,
    ) -> Result<Outcome, ServerError> {
        let now = self.clock.now();
        let mut draft = state.clone();
        let applied = change(&mut draft, now)?;
        match applied.effect {
            ChangeEffect::Discarded => return Ok(applied.outcome),
            ChangeEffect::SavedWithoutRecord => {}
            ChangeEffect::Recorded(record) => {
                let audit_event = AuditEvent {
                    acting_device,
                    text: &record.event_text,
                    detail: record.detail,
                };
                append_audit_event(
                    &mut draft,
                    &self.identity,
                    &audit_event,
                    now,
                );
                append_notification(&mut draft, record.topic);
            }
        }
        draft.revision = draft.revision.saturating_add(1);
        self.replace_state(state, draft)?;
        Ok(applied.outcome)
    }

    fn replace_state(
        &self,
        mut state: MutexGuard<'_, StoredState>,
        replacement: StoredState,
    ) -> Result<(), ServerError> {
        self.storage.save_state(&replacement)?;
        let latest_sequence = replacement.latest_sequence;
        let latest_revision = replacement.revision;
        *state = replacement;
        drop(state);
        self.latest_sequence.send_replace(latest_sequence);
        self.latest_revision.send_replace(latest_revision);
        Ok(())
    }

    #[must_use]
    pub fn subscribe_to_changes(&self) -> watch::Receiver<u64> {
        self.latest_sequence.subscribe()
    }

    #[must_use]
    pub fn subscribe_to_revisions(&self) -> watch::Receiver<u64> {
        self.latest_revision.subscribe()
    }

    pub fn admit_request(
        &self,
        request_signature: &RequestSignature,
        now: DateTime<Utc>,
    ) -> Result<(), ServerError> {
        let mut request_ledger = self
            .request_ledger
            .lock()
            .map_err(|_| ServerError::Internal(POISONED_LEDGER))?;
        request_ledger.admit(request_signature, now)
    }

    pub fn presence_snapshot(&self) -> Result<Presence, ServerError> {
        let request_ledger = self
            .request_ledger
            .lock()
            .map_err(|_| ServerError::Internal(POISONED_LEDGER))?;
        Ok(request_ledger.presence())
    }

    fn lock_state(&self) -> Result<MutexGuard<'_, StoredState>, ServerError> {
        self.state
            .lock()
            .map_err(|_| ServerError::Internal(POISONED_STATE))
    }
}

fn opens_as_active(state: &StoredState, server_id: &DeviceId) -> bool {
    let group = &state.server_group;
    match group.active_server_id() {
        None => true,
        Some(active_server_id) => {
            active_server_id == server_id && !group.has_backups()
        }
    }
}
