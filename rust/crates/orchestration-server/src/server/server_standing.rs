use std::path::Path;
use std::sync::atomic::Ordering;

use orchestration_api::server_group::ServerGroupView;
use orchestration_core::identifiers::DeviceId;
use orchestration_core::server_group::{
    ServerGroup, ServerMember, ServerStanding, ServerTerm,
};

use super::Server;
use crate::error::ServerError;
use crate::persistence::StateStorage;
use crate::replica_check::verify_replica;
use crate::server_group_changes::{
    admit_member, found_group, record_takeover,
};
use crate::stored_state::StoredState;

impl Server {
    pub fn seed_replica(
        data_directory: &Path,
        replica_bytes: &[u8],
        source_server_id: &DeviceId,
    ) -> Result<(), ServerError> {
        let storage = StateStorage::new(data_directory.to_path_buf());
        let identity = storage.load_or_create_identity()?;
        let offered = parse_replica(replica_bytes)?;
        verify_replica(&StoredState::default(), &offered, source_server_id)?;
        let lists_this_server = offered
            .server_group
            .find_member(&identity.device_id())
            .is_some();
        if !lists_this_server {
            return Err(ServerError::Conflict(
                "the copy does not list this app server".to_owned(),
            ));
        }
        storage.save_state(&offered)
    }

    pub fn install_replica(
        &self,
        replica_bytes: &[u8],
        source_server_id: &DeviceId,
    ) -> Result<(), ServerError> {
        let offered = parse_replica(replica_bytes)?;
        let state = self.lock_state()?;
        if self.standing() == ServerStanding::Active {
            return Err(ServerError::Conflict(
                "an active app server takes no copies".to_owned(),
            ));
        }
        verify_replica(&state, &offered, source_server_id)?;
        self.replace_state(state, offered)
    }

    pub fn take_over(&self, term: &ServerTerm) -> Result<(), ServerError> {
        let state = self.lock_state()?;
        let server_id = self.device_id();
        self.apply_locked(state, &term.claimed_by, |draft, _now| {
            record_takeover(draft, term, &server_id)
        })?;
        self.accepts_writes.store(true, Ordering::SeqCst);
        Ok(())
    }

    pub fn step_down(&self) -> Result<(), ServerError> {
        let _state = self.lock_state()?;
        self.accepts_writes.store(false, Ordering::SeqCst);
        Ok(())
    }

    pub fn resume_as_active(&self) -> Result<(), ServerError> {
        let state = self.lock_state()?;
        let names_this_server =
            state.server_group.active_server_id() == Some(&self.device_id());
        if !names_this_server {
            return Err(ServerError::Conflict(
                "the server term names another app server".to_owned(),
            ));
        }
        self.accepts_writes.store(true, Ordering::SeqCst);
        Ok(())
    }

    pub fn found_group(
        &self,
        founder: &ServerMember,
        term: &ServerTerm,
    ) -> Result<ServerGroup, ServerError> {
        let server_id = self.device_id();
        self.apply(&founder.membership.device_id, |state, _now| {
            found_group(state, founder, term, &server_id)
        })
    }

    pub fn register_member(
        &self,
        caller: &DeviceId,
        member: &ServerMember,
    ) -> Result<ServerGroup, ServerError> {
        self.apply(caller, |state, _now| admit_member(state, caller, member))
    }

    pub fn describe_group(&self) -> Result<ServerGroupView, ServerError> {
        let state = self.lock_state()?;
        Ok(ServerGroupView {
            group: state.server_group.clone(),
            standing: self.standing(),
            revision: state.revision,
        })
    }
}

fn parse_replica(replica_bytes: &[u8]) -> Result<StoredState, ServerError> {
    serde_json::from_slice(replica_bytes).map_err(|problem| {
        ServerError::Invalid(format!("the copy is unreadable: {problem}"))
    })
}
