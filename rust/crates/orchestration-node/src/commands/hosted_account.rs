use orchestration_core::device::DeviceRole;

use super::account_commands::AccountSummary;
#[cfg(feature = "app-server")]
use super::account_commands::{
    AccountSetup, create_account, ensure_new_account,
};
#[cfg(feature = "app-server")]
use crate::app_server_hosting::{host_app_server, keep_server_group};
use crate::node::Node;
use crate::node_error::NodeError;

#[derive(Debug)]
#[cfg_attr(not(feature = "app-server"), allow(dead_code))]
pub(super) struct HostedAccountSetup {
    pub(super) workspace_name: String,
    pub(super) device_name: String,
    pub(super) role: DeviceRole,
}

#[cfg(feature = "app-server")]
pub(super) async fn create_hosted_account(
    node: &Node,
    setup: HostedAccountSetup,
) -> Result<AccountSummary, NodeError> {
    ensure_new_account(node, &setup.device_name, &setup.workspace_name)?;
    if setup.role == DeviceRole::Runner {
        return Err(NodeError::HostingNeedsClient);
    }
    let access = host_app_server(node).await?;
    let setup_code =
        access.setup_code.ok_or(NodeError::HostedServerHasAccount)?;
    let account_setup = AccountSetup {
        server_address: access.local_address,
        setup_code,
        device_name: setup.device_name,
        role: setup.role,
        workspace_name: setup.workspace_name,
    };
    let summary = create_account(node, account_setup).await?;
    keep_server_group(node)?;
    Ok(summary)
}

#[cfg(not(feature = "app-server"))]
pub(super) fn create_hosted_account(
    _node: &Node,
    _setup: HostedAccountSetup,
) -> std::future::Ready<Result<AccountSummary, NodeError>> {
    std::future::ready(Err(NodeError::HostingUnavailable))
}
