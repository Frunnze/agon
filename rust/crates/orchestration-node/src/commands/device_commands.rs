use orchestration_api::accounts::{RevokeDeviceRequest, revocation_statement};
use orchestration_api::catalog::{
    AddWorkspaceDeviceRequest, CreateWorkspaceRequest,
};
use orchestration_core::device::Device;
use orchestration_core::identifiers::{DeviceId, WorkspaceId, generate_uuid};
use orchestration_core::naming::validate_name;
use orchestration_core::workspace::{Project, Workspace};
use orchestration_security::sealing::WorkspaceKey;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::command_reply::encode_reply;
use crate::content_sealing::seal_workspace_key;
use crate::device_roles::can_run_tasks;
use crate::node::{DeviceSession, Node};
use crate::node_error::NodeError;
use crate::peer_side::trusted_peer_address;

pub(super) const DEVICE_COMMAND_NAMES: [&str; 7] = [
    "list_devices",
    "revoke_device",
    "list_workspaces",
    "create_workspace",
    "add_device_to_workspace",
    "remove_device_from_workspace",
    "list_audit",
];

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum DeviceCommand {
    ListDevices,
    RevokeDevice {
        device_id: DeviceId,
    },
    ListWorkspaces,
    CreateWorkspace {
        name: String,
    },
    AddDeviceToWorkspace {
        workspace_id: WorkspaceId,
        device_id: DeviceId,
    },
    RemoveDeviceFromWorkspace {
        workspace_id: WorkspaceId,
        device_id: DeviceId,
    },
    ListAudit,
}

#[derive(Debug, Serialize)]
struct DeviceView {
    device: Device,
    is_this_device: bool,
    workspace_names: Vec<String>,
    peer_address_verified: bool,
}

#[derive(Debug, Serialize)]
struct WorkspaceView {
    workspace: Workspace,
    project_count: usize,
    runner_count: usize,
}

pub(super) async fn handle_device_command(
    node: &Node,
    command: DeviceCommand,
) -> Result<Value, NodeError> {
    let session = node.open_session()?;
    let client = session.client();
    match command {
        DeviceCommand::ListDevices => {
            let devices = client.list_devices().await?;
            let workspaces = client.list_workspaces().await?;
            encode_reply(&build_device_views(&session, &devices, &workspaces))
        }
        DeviceCommand::RevokeDevice { device_id } => {
            let statement = revocation_statement(&device_id);
            let request = RevokeDeviceRequest {
                approval_signature: session.identity.sign(&statement),
            };
            client.revoke_device(&device_id, &request).await?;
            Ok(Value::Null)
        }
        DeviceCommand::ListWorkspaces => {
            let workspaces = client.list_workspaces().await?;
            let projects = client.list_projects().await?;
            let devices = client.list_devices().await?;
            encode_reply(&build_workspace_views(
                &workspaces,
                &projects,
                &devices,
            ))
        }
        DeviceCommand::CreateWorkspace { name } => {
            encode_reply(&create_workspace(node, &session, name).await?)
        }
        DeviceCommand::AddDeviceToWorkspace {
            workspace_id,
            device_id,
        } => {
            let devices = client.list_devices().await?;
            let device = find_device(&devices, &device_id)?;
            let workspace_key = session.keyring.key_for(workspace_id)?;
            let request = AddWorkspaceDeviceRequest {
                device_id,
                sealed_workspace_key: seal_workspace_key(
                    &device.sealing_public_key,
                    workspace_key,
                )?,
            };
            client.add_workspace_device(workspace_id, &request).await?;
            Ok(Value::Null)
        }
        DeviceCommand::RemoveDeviceFromWorkspace {
            workspace_id,
            device_id,
        } => {
            client
                .remove_workspace_device(workspace_id, &device_id)
                .await?;
            Ok(Value::Null)
        }
        DeviceCommand::ListAudit => encode_reply(&client.read_audit().await?),
    }
}

fn find_device<'devices>(
    devices: &'devices [Device],
    device_id: &DeviceId,
) -> Result<&'devices Device, NodeError> {
    devices
        .iter()
        .find(|device| &device.id == device_id)
        .ok_or_else(|| NodeError::NotFound {
            kind: "device",
            identifier: device_id.0.clone(),
        })
}

fn build_device_views(
    session: &DeviceSession,
    devices: &[Device],
    workspaces: &[Workspace],
) -> Vec<DeviceView> {
    let this_device_id = session.identity.device_id();
    let mut device_views = Vec::new();
    for device in devices {
        let mut workspace_names = Vec::new();
        for workspace in workspaces {
            if device.workspaces.contains(&workspace.id) {
                workspace_names.push(workspace.name.clone());
            }
        }
        device_views.push(DeviceView {
            device: device.clone(),
            is_this_device: device.id == this_device_id,
            workspace_names,
            peer_address_verified: trusted_peer_address(device).is_ok(),
        });
    }
    device_views
}

fn build_workspace_views(
    workspaces: &[Workspace],
    projects: &[Project],
    devices: &[Device],
) -> Vec<WorkspaceView> {
    let mut workspace_views = Vec::new();
    for workspace in workspaces {
        let project_count = projects
            .iter()
            .filter(|project| project.workspace_id == workspace.id)
            .count();
        let runner_count = devices
            .iter()
            .filter(|device| device.workspaces.contains(&workspace.id))
            .filter(|device| !device.revoked && can_run_tasks(device.role))
            .count();
        workspace_views.push(WorkspaceView {
            workspace: workspace.clone(),
            project_count,
            runner_count,
        });
    }
    workspace_views
}

async fn create_workspace(
    node: &Node,
    session: &DeviceSession,
    name: String,
) -> Result<Workspace, NodeError> {
    validate_name(&name)?;
    let own_sealing_key =
        session.identity.public_identity().sealing_public_key;
    let workspace_key = WorkspaceKey::generate()?;
    let workspace_id = WorkspaceId(generate_uuid());
    let request = CreateWorkspaceRequest {
        workspace_id,
        name,
        sealed_workspace_key: seal_workspace_key(
            &own_sealing_key,
            &workspace_key,
        )?,
    };

    let client = session.client();
    client.create_workspace(&request).await?;
    let fresh_account = client.read_account().await?;
    node.device_files().save_account(&fresh_account)?;

    let created_workspace = fresh_account
        .workspaces
        .into_iter()
        .find(|workspace| workspace.id == workspace_id);
    created_workspace.ok_or_else(|| NodeError::NotFound {
        kind: "workspace",
        identifier: workspace_id.0.to_string(),
    })
}
