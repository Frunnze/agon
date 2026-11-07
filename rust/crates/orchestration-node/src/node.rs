mod agent_login_access;
mod app_server_access;
mod hosting_problem_access;

use std::sync::{Arc, Mutex, MutexGuard, OnceLock, PoisonError, RwLock};
#[cfg(feature = "app-server")]
use std::time::Duration;

use orchestration_api::accounts::AccountView;
use orchestration_core::agent_place::AgentPlace;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::peer_addresses::{
    PeerSecret, generate_peer_secret,
};

use crate::agent_credentials::AgentCredentials;
#[cfg(feature = "runner")]
use crate::agent_login::AgentLoginDesk;
#[cfg(feature = "app-server")]
use crate::app_server_hosting::HostedAppServer;
use crate::approver_pairings::ApproverPairings;
use crate::code_rendezvous::PublishedCodes;
use crate::content_sealing::WorkspaceKeyring;
use crate::device_files::DeviceFiles;
use crate::identity_store::{IdentityStore, open_identity_store};
use crate::node_configuration::{NodeConfiguration, PeerRelayChoice};
use crate::node_error::NodeError;
use crate::peer_side::PeerSide;
use crate::place_offers::normalize_offers;
use crate::runner_state::RunnerState;
use crate::server_address::ServerAddress;
use crate::server_client::{PeerDialer, ServerClient, SignedServerClient};
use app_server_access::connect_recorded_server;

type CachedIdentity = Option<Arc<DeviceIdentity>>;

#[derive(Debug)]
pub struct DeviceSession {
    pub identity: Arc<DeviceIdentity>,
    pub account: AccountView,
    pub keyring: WorkspaceKeyring,
    pub server: ServerClient,
}

impl DeviceSession {
    #[must_use]
    pub fn client(&self) -> SignedServerClient<'_> {
        self.server.signed(&self.identity)
    }
}

#[derive(Debug)]
pub struct Node {
    identity_store: Arc<dyn IdentityStore>,
    agent_credentials: Arc<AgentCredentials>,
    #[cfg(feature = "runner")]
    agent_login_desk: AgentLoginDesk,
    device_files: DeviceFiles,
    cached_identity: Mutex<CachedIdentity>,
    app_server: RwLock<Option<ServerClient>>,
    server_dialer: Arc<PeerDialer>,
    peer_relay: PeerRelayChoice,
    published_codes: Arc<PublishedCodes>,
    approver_pairings: ApproverPairings,
    peer_side: OnceLock<Arc<PeerSide>>,
    runner_state: RunnerState,
    #[cfg(feature = "app-server")]
    app_server_port: u16,
    #[cfg(feature = "app-server")]
    takeover_after: Duration,
    #[cfg(feature = "app-server")]
    hosted_app_server: Mutex<Option<HostedAppServer>>,
    hosting_problem: Mutex<Option<String>>,
}

impl Node {
    pub fn open(configuration: &NodeConfiguration) -> Result<Self, NodeError> {
        let device_files = DeviceFiles::open(&configuration.data_directory)?;
        let identity_store: Arc<dyn IdentityStore> = Arc::from(
            open_identity_store(&configuration.identity_store, &device_files)?,
        );
        let agent_credentials =
            Arc::new(AgentCredentials::open(Arc::clone(&identity_store))?);
        let relay_choice = configuration.peer_relay.to_relay_choice();
        let server_dialer = Arc::new(PeerDialer::new(relay_choice));
        let app_server =
            connect_recorded_server(&device_files, &server_dialer, None)?;
        let runner_state = RunnerState::new(device_files.load_agent_offers()?);
        Ok(Self {
            identity_store,
            agent_credentials,
            #[cfg(feature = "runner")]
            agent_login_desk: AgentLoginDesk::default(),
            device_files,
            cached_identity: Mutex::new(None),
            app_server: RwLock::new(app_server),
            server_dialer,
            peer_relay: configuration.peer_relay.clone(),
            published_codes: Arc::default(),
            approver_pairings: ApproverPairings::default(),
            peer_side: OnceLock::new(),
            runner_state,
            #[cfg(feature = "app-server")]
            app_server_port: configuration.app_server_port,
            #[cfg(feature = "app-server")]
            takeover_after: Duration::from_secs(
                configuration.server_takeover_seconds,
            ),
            #[cfg(feature = "app-server")]
            hosted_app_server: Mutex::new(None),
            hosting_problem: Mutex::new(None),
        })
    }

    #[must_use]
    pub fn device_files(&self) -> &DeviceFiles {
        &self.device_files
    }

    pub fn forget_identity(&self) -> Result<(), NodeError> {
        let mut cached_identity = self.lock_identity();
        self.identity_store
            .forget_identity()
            .map_err(NodeError::IdentityNotForgotten)?;
        *cached_identity = None;
        Ok(())
    }

    pub fn forget_device_records(&self) -> Result<(), NodeError> {
        self.identity_store.forget_peer_secret()?;
        self.device_files.remove_device_records()?;
        *self.write_app_server() = None;
        Ok(())
    }

    pub(crate) fn server_dialer(&self) -> &PeerDialer {
        &self.server_dialer
    }

    #[cfg(feature = "app-server")]
    pub(crate) fn shared_server_dialer(&self) -> Arc<PeerDialer> {
        Arc::clone(&self.server_dialer)
    }

    #[cfg(feature = "app-server")]
    pub(crate) fn peer_relay(&self) -> &PeerRelayChoice {
        &self.peer_relay
    }

    pub(crate) fn crosses_networks(&self) -> bool {
        self.peer_relay != PeerRelayChoice::Disabled
    }

    pub(crate) fn published_codes(&self) -> Arc<PublishedCodes> {
        Arc::clone(&self.published_codes)
    }

    pub(crate) fn approver_pairings(&self) -> &ApproverPairings {
        &self.approver_pairings
    }

    pub fn find_identity(&self) -> Result<CachedIdentity, NodeError> {
        let mut cached_identity = self.lock_identity();
        self.load_into_cache(&mut cached_identity)
    }

    pub fn find_or_create_identity(
        &self,
    ) -> Result<Arc<DeviceIdentity>, NodeError> {
        let mut cached_identity = self.lock_identity();
        if let Some(identity) = self.load_into_cache(&mut cached_identity)? {
            return Ok(identity);
        }
        let identity = DeviceIdentity::generate()?;
        self.identity_store.save_identity(&identity)?;
        let shared_identity = Arc::new(identity);
        *cached_identity = Some(Arc::clone(&shared_identity));
        Ok(shared_identity)
    }

    pub fn open_session(&self) -> Result<DeviceSession, NodeError> {
        let identity = self.find_identity()?.ok_or(NodeError::NoAccount)?;
        let account = self
            .device_files
            .load_account()?
            .ok_or(NodeError::NoAccount)?;
        let keyring = WorkspaceKeyring::open_sealed_keys(
            &identity,
            &account.sealed_workspace_keys,
        )?;
        Ok(DeviceSession {
            identity,
            account,
            keyring,
            server: self.app_server()?,
        })
    }

    pub fn find_or_create_peer_secret(&self) -> Result<PeerSecret, NodeError> {
        if let Some(peer_secret) = self.identity_store.load_peer_secret()? {
            return Ok(peer_secret);
        }
        let peer_secret = generate_peer_secret()?;
        self.identity_store.save_peer_secret(&peer_secret)?;
        Ok(peer_secret)
    }

    pub(crate) fn attach_peer_side(&self, peer_side: Arc<PeerSide>) {
        let _already_attached = self.peer_side.set(peer_side);
    }

    pub(crate) fn peer_side(&self) -> Result<&PeerSide, NodeError> {
        self.peer_side
            .get()
            .map(AsRef::as_ref)
            .ok_or(NodeError::NoPeerEndpoint)
    }

    #[must_use]
    pub fn runner_state(&self) -> &RunnerState {
        &self.runner_state
    }

    pub fn choose_agent_offers(
        &self,
        offers: &[AgentPlace],
    ) -> Result<(), NodeError> {
        if self.runner_state.settings_in_effect().is_none() {
            return Err(NodeError::RunnerUnavailable);
        }
        if offers.is_empty() {
            return Err(NodeError::NoAgentOffers);
        }
        let normalized_offers = normalize_offers(offers);
        self.device_files.save_agent_offers(&normalized_offers)?;
        self.runner_state.remember_chosen_offers(normalized_offers);
        Ok(())
    }

    #[cfg(feature = "app-server")]
    pub(crate) fn app_server_port(&self) -> u16 {
        self.app_server_port
    }

    #[cfg(feature = "app-server")]
    pub(crate) fn takeover_after(&self) -> Duration {
        self.takeover_after
    }

    #[cfg(feature = "app-server")]
    pub(crate) fn hosted_server_address(&self) -> Option<ServerAddress> {
        let hosted_slot = self.lock_hosted_app_server();
        hosted_slot.as_ref().map(HostedAppServer::public_address)
    }

    #[cfg(not(feature = "app-server"))]
    #[allow(clippy::unused_self)]
    pub(crate) fn hosted_server_address(&self) -> Option<ServerAddress> {
        None
    }

    #[cfg(feature = "app-server")]
    pub(crate) fn lock_hosted_app_server(
        &self,
    ) -> MutexGuard<'_, Option<HostedAppServer>> {
        self.hosted_app_server
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
    }

    fn load_into_cache(
        &self,
        cached_identity: &mut CachedIdentity,
    ) -> Result<CachedIdentity, NodeError> {
        if cached_identity.is_none() {
            let stored_identity = self.identity_store.load_identity()?;
            *cached_identity = stored_identity.map(Arc::new);
        }
        Ok(cached_identity.clone())
    }

    fn lock_identity(&self) -> MutexGuard<'_, CachedIdentity> {
        self.cached_identity
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
    }
}
