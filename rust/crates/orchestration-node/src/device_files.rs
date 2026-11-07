use std::fs;
use std::io::ErrorKind;
use std::path::{Path, PathBuf};

use orchestration_api::accounts::AccountView;
use orchestration_core::agent_place::AgentPlace;
use orchestration_core::server_group::ServerGroup;
use orchestration_security::pairing::PairingPublicKeys;
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::file_removal::remove_file_if_present;
use crate::node_error::NodeError;
use crate::place_offers::StoredOffers;

const ACCOUNT_FILE_NAME: &str = "account.json";
const PENDING_JOIN_FILE_NAME: &str = "pending-join.json";
const IDENTITY_FILE_NAME: &str = "device-identity.key";
const SEALED_IDENTITY_FILE_NAME: &str = "device-identity.sealed";
const SERVER_FILE_NAME: &str = "app-server.json";
const HOSTED_SERVER_FILE_NAME: &str = "hosted-app-server.json";
const HOSTED_SERVER_DIRECTORY_NAME: &str = "hosted-app-server";
const SERVER_GROUP_FILE_NAME: &str = "server-group.json";
const AGENT_PLACE_FILE_NAME: &str = "agent-place.json";
pub(crate) const REPOSITORY_CACHE_DIRECTORY_NAME: &str = "repository-cache";
const TEMPORARY_SUFFIX: &str = "incomplete";
const DEVICE_RECORD_FILE_NAMES: [&str; 4] = [
    ACCOUNT_FILE_NAME,
    PENDING_JOIN_FILE_NAME,
    SERVER_FILE_NAME,
    SERVER_GROUP_FILE_NAME,
];

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PendingJoin {
    pub join_id: Uuid,
    pub display_code: String,
    #[serde(default)]
    pub joiner_nonce: Vec<u8>,
    #[serde(default)]
    pub approver: PairingPublicKeys,
    #[serde(default)]
    pub approver_commitment: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct PendingJoinView {
    pub join_id: Uuid,
    pub display_code: String,
}

impl PendingJoin {
    #[must_use]
    pub fn view(&self) -> PendingJoinView {
        PendingJoinView {
            join_id: self.join_id,
            display_code: self.display_code.clone(),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppServerRecord {
    pub server_address: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct HostedServerRecord {
    pub port: u16,
}

#[derive(Debug)]
pub struct DeviceFiles {
    data_directory: PathBuf,
}

impl DeviceFiles {
    pub fn open(data_directory: &Path) -> Result<Self, NodeError> {
        fs::create_dir_all(data_directory)?;
        Ok(Self {
            data_directory: data_directory.to_path_buf(),
        })
    }

    #[must_use]
    pub fn identity_path(&self) -> PathBuf {
        self.data_directory.join(IDENTITY_FILE_NAME)
    }

    #[must_use]
    pub fn sealed_identity_path(&self) -> PathBuf {
        self.data_directory.join(SEALED_IDENTITY_FILE_NAME)
    }

    pub fn load_account(&self) -> Result<Option<AccountView>, NodeError> {
        read_json_file(&self.data_directory.join(ACCOUNT_FILE_NAME))
    }

    pub fn save_account(
        &self,
        account: &AccountView,
    ) -> Result<(), NodeError> {
        write_json_file(&self.data_directory.join(ACCOUNT_FILE_NAME), account)
    }

    pub fn load_app_server(
        &self,
    ) -> Result<Option<AppServerRecord>, NodeError> {
        read_json_file(&self.data_directory.join(SERVER_FILE_NAME))
    }

    pub fn save_app_server(
        &self,
        app_server: &AppServerRecord,
    ) -> Result<(), NodeError> {
        write_json_file(
            &self.data_directory.join(SERVER_FILE_NAME),
            app_server,
        )
    }

    pub fn load_server_group(&self) -> Result<Option<ServerGroup>, NodeError> {
        read_json_file(&self.data_directory.join(SERVER_GROUP_FILE_NAME))
    }

    pub fn save_server_group(
        &self,
        server_group: &ServerGroup,
    ) -> Result<(), NodeError> {
        let path = self.data_directory.join(SERVER_GROUP_FILE_NAME);
        write_json_file(&path, server_group)
    }

    #[must_use]
    pub fn hosted_server_directory(&self) -> PathBuf {
        self.data_directory.join(HOSTED_SERVER_DIRECTORY_NAME)
    }

    #[must_use]
    pub fn repository_cache_directory(&self) -> PathBuf {
        self.data_directory.join(REPOSITORY_CACHE_DIRECTORY_NAME)
    }

    #[must_use]
    pub fn hosted_server_record_path(&self) -> PathBuf {
        self.data_directory.join(HOSTED_SERVER_FILE_NAME)
    }

    pub fn load_hosted_server(
        &self,
    ) -> Result<Option<HostedServerRecord>, NodeError> {
        read_json_file(&self.hosted_server_record_path())
    }

    pub fn save_hosted_server(
        &self,
        hosted_server: &HostedServerRecord,
    ) -> Result<(), NodeError> {
        write_json_file(&self.hosted_server_record_path(), hosted_server)
    }

    pub fn load_pending_join(&self) -> Result<Option<PendingJoin>, NodeError> {
        read_json_file(&self.data_directory.join(PENDING_JOIN_FILE_NAME))
    }

    pub fn save_pending_join(
        &self,
        pending_join: &PendingJoin,
    ) -> Result<(), NodeError> {
        let path = self.data_directory.join(PENDING_JOIN_FILE_NAME);
        write_json_file(&path, pending_join)
    }

    pub fn remove_pending_join(&self) -> Result<(), NodeError> {
        let path = self.data_directory.join(PENDING_JOIN_FILE_NAME);
        remove_file_if_present(&path)?;
        Ok(())
    }

    pub fn load_agent_offers(
        &self,
    ) -> Result<Option<Vec<AgentPlace>>, NodeError> {
        let path = self.data_directory.join(AGENT_PLACE_FILE_NAME);
        let stored: Option<StoredOffers> = read_json_file(&path)?;
        Ok(stored.map(StoredOffers::into_offers))
    }

    pub fn save_agent_offers(
        &self,
        offers: &[AgentPlace],
    ) -> Result<(), NodeError> {
        let path = self.data_directory.join(AGENT_PLACE_FILE_NAME);
        write_json_file(&path, &offers)
    }

    pub fn remove_device_records(&self) -> Result<(), NodeError> {
        for file_name in DEVICE_RECORD_FILE_NAMES {
            remove_file_if_present(&self.data_directory.join(file_name))?;
        }
        Ok(())
    }
}

pub(crate) fn read_json_file<Stored: DeserializeOwned>(
    path: &Path,
) -> Result<Option<Stored>, NodeError> {
    let stored_bytes = match fs::read(path) {
        Ok(stored_bytes) => stored_bytes,
        Err(error) if error.kind() == ErrorKind::NotFound => return Ok(None),
        Err(error) => return Err(NodeError::Storage(error)),
    };
    let stored_value = serde_json::from_slice(&stored_bytes)?;
    Ok(Some(stored_value))
}

pub(crate) fn write_json_file<Stored: Serialize>(
    path: &Path,
    stored_value: &Stored,
) -> Result<(), NodeError> {
    let temporary_path = choose_temporary_path(path);
    let stored_bytes = serde_json::to_vec_pretty(stored_value)?;
    fs::write(&temporary_path, stored_bytes)?;
    fs::rename(&temporary_path, path)?;
    Ok(())
}

fn choose_temporary_path(path: &Path) -> PathBuf {
    let unique_suffix =
        format!("{}.{TEMPORARY_SUFFIX}", Uuid::new_v4().simple());
    path.with_extension(unique_suffix)
}
