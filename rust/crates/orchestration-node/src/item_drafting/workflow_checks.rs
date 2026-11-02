use orchestration_core::identifiers::WorkspaceId;
use orchestration_core::naming::validate_name;
use orchestration_core::scope::WorkspaceScope;
use orchestration_core::workflow::Workflow;

use crate::node_error::NodeError;

const UNOFFERED_AVAILABILITY: &str =
    "it must be available in this workspace only or in all workspaces";

pub fn check_new_workflow_draft(
    drafted: &Workflow,
    workspace_id: WorkspaceId,
    taken_names: &[String],
) -> Result<(), NodeError> {
    validate_name(&drafted.name)
        .map_err(|problem| NodeError::DraftNotWorkflow(problem.to_string()))?;
    if taken_names.contains(&drafted.name) {
        return Err(NodeError::DraftNotWorkflow(format!(
            "another workflow is already named {}",
            drafted.name
        )));
    }

    let this_workspace_only = WorkspaceScope::OnlyWorkspaces {
        workspaces: vec![workspace_id],
    };
    let is_offered = drafted.availability == WorkspaceScope::AllWorkspaces
        || drafted.availability == this_workspace_only;
    if !is_offered {
        return Err(NodeError::DraftNotWorkflow(
            UNOFFERED_AVAILABILITY.to_owned(),
        ));
    }
    Ok(())
}
