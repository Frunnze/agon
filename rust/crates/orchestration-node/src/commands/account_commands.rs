use chrono::{DateTime, Utc};
use orchestration_api::accounts::{AccountView, CreateAccountRequest};
use orchestration_api::updates::ChangeTopic;
use orchestration_core::device::{Device, DeviceRole};
use orchestration_core::identifiers::{DeviceId, WorkspaceId, generate_uuid};
use orchestration_core::naming::validate_name;
use orchestration_core::workspace::Workspace;
use orchestration_security::sealing::WorkspaceKey;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::device_forgetting::forget_this_device;
use super::device_registration::register_this_device;
use super::hosted_account::{HostedAccountSetup, create_hosted_account};
use crate::command_reply::encode_reply;
use crate::content_sealing::seal_workspace_key;
use crate::device_files::{PendingJoin, PendingJoinView};
use crate::node::Node;
use crate::node_error::NodeError;
use crate::peer_side::{AnnouncementState, PeerSide};
use crate::runner_settings::RunnerSettings;
use crate::server_address::ServerAddress;
use crate::views::{
    AppServersView, describe_app_servers, describe_fresh_app_servers,
};

const GROUP_CHANGE_TOPICS: [ChangeTopic; 2] =
    [ChangeTopic::ServerGroup, ChangeTopic::Devices];

pub(super) const ACCOUNT_COMMAND_NAMES: [&str; 6] = [
    "status",
    "create_account",
    "create_hosted_account",
    "retry_server",
    "poll_events",
    "forget_this_device",
];

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum AccountCommand {
    Status {},
    CreateAccount {
        server_address: String,
        setup_code: String,
        device_name: String,
        role: DeviceRole,
        workspace_name: String,
    },
    CreateHostedAccount {
        workspace_name: String,
        device_name: String,
        role: DeviceRole,
    },
    RetryServer {},
    PollEvents {
        after: u64,
    },
    ForgetThisDevice {},
}

#[derive(Debug, Serialize)]
pub(super) struct AccountSummary {
    pub(super) device: Device,
    pub(super) workspaces: Vec<Workspace>,
}

#[derive(Debug, Serialize)]
struct ServerHealthView {
    reachable: bool,
    checked_at: DateTime<Utc>,
    problem: Option<String>,
}

#[derive(Debug)]
pub(super) struct AccountSetup {
    pub(super) server_address: String,
    pub(super) setup_code: String,
    pub(super) device_name: String,
    pub(super) role: DeviceRole,
    pub(super) workspace_name: String,
}

#[derive(Debug, Serialize)]
struct StatusView {
    server_address: Option<String>,
    server_reachable: bool,
    hosted_server_address: Option<String>,
    hosting_problem: Option<String>,
    device_id: Option<DeviceId>,
    account: Option<AccountSummary>,
    pending_join: Option<PendingJoinView>,
    peer: Option<AnnouncementState>,
    rendezvous_problem: Option<String>,
    runner_settings: Option<RunnerSettings>,
    runner_problem: Option<String>,
    app_servers: AppServersView,
}

pub(super) async fn handle_account_command(
    node: &Node,
    command: AccountCommand,
) -> Result<Value, NodeError> {
    match command {
        AccountCommand::Status {} => {
            encode_reply(&describe_status(node).await?)
        }
        AccountCommand::CreateAccount {
            server_address,
            setup_code,
            device_name,
            role,
            workspace_name,
        } => {
            let setup = AccountSetup {
                server_address,
                setup_code,
                device_name,
                role,
                workspace_name,
            };
            encode_reply(&create_account(node, setup).await?)
        }
        AccountCommand::CreateHostedAccount {
            workspace_name,
            device_name,
            role,
        } => {
            let setup = HostedAccountSetup {
                workspace_name,
                device_name,
                role,
            };
            encode_reply(&create_hosted_account(node, setup).await?)
        }
        AccountCommand::RetryServer {} => {
            encode_reply(&check_server(node).await)
        }
        AccountCommand::PollEvents { after } => {
            let session = node.open_session()?;
            let events = session.client().poll_events(after).await?;
            let has_group_change =
                events.notifications.iter().any(|notification| {
                    GROUP_CHANGE_TOPICS.contains(&notification.topic)
                });
            if has_group_change {
                node.refresh_server_group(&session).await?;
            }
            encode_reply(&events)
        }
        AccountCommand::ForgetThisDevice {} => {
            forget_this_device(node).await?;
            Ok(Value::Null)
        }
    }
}

pub(super) fn summarize_account(account: &AccountView) -> AccountSummary {
    AccountSummary {
        device: account.device.clone(),
        workspaces: account.workspaces.clone(),
    }
}

async fn check_server(node: &Node) -> ServerHealthView {
    let health = match node.app_server() {
        Ok(server) => server.check_health().await,
        Err(error) => Err(error),
    };
    ServerHealthView {
        reachable: health.is_ok(),
        checked_at: Utc::now(),
        problem: health.err().map(|error| error.to_string()),
    }
}

async fn describe_status(node: &Node) -> Result<StatusView, NodeError> {
    let identity = node.find_identity()?;
    let health = check_server(node).await;
    let mut account = node.device_files().load_account()?;

    let can_refresh_account = account.is_some() && health.reachable;
    let mut fresh_group_view = None;
    if can_refresh_account {
        let session = node.open_session()?;
        let fresh_account = session.client().read_account().await?;
        node.device_files().save_account(&fresh_account)?;
        account = Some(fresh_account);
        fresh_group_view = Some(node.refresh_server_group(&session).await?);
    }
    let own_device = account.as_ref().map(|known| &known.device);
    let app_servers = if let Some(fresh_view) = &fresh_group_view {
        describe_fresh_app_servers(fresh_view, own_device)
    } else {
        let stored_group = node.device_files().load_server_group()?;
        describe_app_servers(stored_group.as_ref(), own_device)
    };

    let app_server = node.device_files().load_app_server()?;
    let hosted_address = node.hosted_server_address();
    Ok(StatusView {
        server_address: app_server.map(|record| record.server_address),
        server_reachable: health.reachable,
        hosted_server_address: hosted_address
            .map(|address| address.to_string()),
        hosting_problem: node.hosting_problem(),
        device_id: identity.map(|identity| identity.device_id()),
        account: account.as_ref().map(summarize_account),
        pending_join: node
            .device_files()
            .load_pending_join()?
            .as_ref()
            .map(PendingJoin::view),
        peer: node.peer_side().ok().map(PeerSide::announcement),
        rendezvous_problem: node.published_codes().problem(),
        runner_settings: node.runner_state().settings_in_effect(),
        runner_problem: node.runner_state().problem(),
        app_servers,
    })
}

pub(super) fn ensure_new_account(
    node: &Node,
    device_name: &str,
    workspace_name: &str,
) -> Result<(), NodeError> {
    validate_name(device_name)?;
    validate_name(workspace_name)?;
    if node.device_files().load_account()?.is_some() {
        return Err(NodeError::AccountExists);
    }
    Ok(())
}

pub(super) async fn create_account(
    node: &Node,
    setup: AccountSetup,
) -> Result<AccountSummary, NodeError> {
    if setup.setup_code.trim().is_empty() {
        return Err(NodeError::EmptyText {
            field: "setup code",
        });
    }
    ensure_new_account(node, &setup.device_name, &setup.workspace_name)?;
    let server_address = ServerAddress::parse(&setup.server_address)?;
    let server = node.connect_to_server(&server_address)?;

    let identity = node.find_or_create_identity()?;
    let own_sealing_key = identity.public_identity().sealing_public_key;
    let workspace_key = WorkspaceKey::generate()?;
    let request = CreateAccountRequest {
        device: register_this_device(&identity, setup.device_name, setup.role),
        workspace_id: WorkspaceId(generate_uuid()),
        workspace_name: setup.workspace_name,
        sealed_workspace_key: seal_workspace_key(
            &own_sealing_key,
            &workspace_key,
        )?,
        setup_code: setup.setup_code,
    };

    let account = server.signed(&identity).create_account(&request).await?;
    node.device_files().save_account(&account)?;
    node.remember_app_server(&server)?;
    node.device_files().remove_pending_join()?;
    Ok(summarize_account(&account))
}
