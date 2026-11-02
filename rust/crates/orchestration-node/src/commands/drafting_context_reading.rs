use orchestration_core::device::Device;
use orchestration_core::identifiers::{DeviceId, WorkspaceId};
use orchestration_core::scope_rules::workspace_scope_includes;
use orchestration_core::workspace::Project;

use crate::item_drafting::{
    DraftingContext, DraftingDevice, DraftingRunner, DraftingSkill,
    DraftingWorkflow, DraftingWorkspace,
};
use crate::node_error::NodeError;
use crate::server_client::SignedServerClient;

pub(super) async fn read_drafting_context(
    client: &SignedServerClient<'_>,
    workspace_id: WorkspaceId,
    this_device_id: &DeviceId,
) -> Result<DraftingContext, NodeError> {
    let devices = client.list_devices().await?;
    Ok(DraftingContext {
        workspace: read_workspace(client, workspace_id).await?,
        this_device: find_device(&devices, this_device_id)?,
        projects: read_projects(client, workspace_id).await?,
        workflows: read_workflows(client, workspace_id).await?,
        skills: read_skills(client, workspace_id).await?,
        runners: read_runners(client, &devices, workspace_id).await?,
    })
}

async fn read_workspace(
    client: &SignedServerClient<'_>,
    workspace_id: WorkspaceId,
) -> Result<DraftingWorkspace, NodeError> {
    let workspaces = client.list_workspaces().await?;
    let workspace = workspaces
        .into_iter()
        .find(|workspace| workspace.id == workspace_id)
        .ok_or_else(|| NodeError::NotFound {
            kind: "workspace",
            identifier: workspace_id.0.to_string(),
        })?;
    Ok(DraftingWorkspace {
        id: workspace.id,
        name: workspace.name,
    })
}

fn find_device(
    devices: &[Device],
    device_id: &DeviceId,
) -> Result<DraftingDevice, NodeError> {
    let device = devices
        .iter()
        .find(|device| device.id == *device_id)
        .ok_or_else(|| NodeError::NotFound {
            kind: "device",
            identifier: device_id.0.clone(),
        })?;
    Ok(DraftingDevice {
        id: device.id.clone(),
        name: device.name.clone(),
    })
}

async fn read_projects(
    client: &SignedServerClient<'_>,
    workspace_id: WorkspaceId,
) -> Result<Vec<Project>, NodeError> {
    let mut workspace_projects = client.list_projects().await?;
    workspace_projects.retain(|project| project.workspace_id == workspace_id);
    Ok(workspace_projects)
}

async fn read_workflows(
    client: &SignedServerClient<'_>,
    workspace_id: WorkspaceId,
) -> Result<Vec<DraftingWorkflow>, NodeError> {
    let mut available_workflows = Vec::new();
    for listing in client.list_workflows().await? {
        let workflow = listing.workflow;
        if workspace_scope_includes(&workflow.availability, workspace_id) {
            available_workflows.push(DraftingWorkflow {
                id: workflow.id,
                name: workflow.name,
                is_signed: workflow.signature.is_some(),
            });
        }
    }
    Ok(available_workflows)
}

async fn read_skills(
    client: &SignedServerClient<'_>,
    workspace_id: WorkspaceId,
) -> Result<Vec<DraftingSkill>, NodeError> {
    let mut usable_skills = Vec::new();
    for skill in client.list_skills().await? {
        if workspace_scope_includes(&skill.scope.workspaces, workspace_id) {
            usable_skills.push(DraftingSkill {
                id: skill.id,
                name: skill.name,
                summary: skill.summary,
                usage: skill.usage,
            });
        }
    }
    Ok(usable_skills)
}

async fn read_runners(
    client: &SignedServerClient<'_>,
    devices: &[Device],
    workspace_id: WorkspaceId,
) -> Result<Vec<DraftingRunner>, NodeError> {
    let mut workspace_runners = Vec::new();
    for runner in client.list_runners().await? {
        let device = devices.iter().find(|device| {
            device.id == runner.device_id
                && !device.revoked
                && device.workspaces.contains(&workspace_id)
        });
        if let Some(device) = device {
            workspace_runners.push(DraftingRunner {
                device: DraftingDevice {
                    id: device.id.clone(),
                    name: device.name.clone(),
                },
                is_online: runner.online,
                labels: runner.labels,
            });
        }
    }
    Ok(workspace_runners)
}
