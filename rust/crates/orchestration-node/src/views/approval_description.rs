use std::collections::BTreeMap;

use orchestration_core::approval::ApprovalAction;
use orchestration_core::identifiers::WorkflowId;

#[must_use]
pub fn describe_approval_action(
    action: &ApprovalAction,
    workflow_names: &BTreeMap<WorkflowId, String>,
) -> String {
    match action {
        ApprovalAction::PushCommits {
            repository,
            commits,
            ..
        } => {
            let commit_word = if commits.len() == 1 {
                "commit"
            } else {
                "commits"
            };
            format!("Push {} {commit_word} to {repository}", commits.len())
        }
        ApprovalAction::Deploy { target } => format!("Deploy to {target}"),
        ApprovalAction::DeleteBranchOrFiles { repository, what } => {
            format!("Delete {what} in {repository}")
        }
        ApprovalAction::SignWorkflow { workflow_id } => {
            let workflow_name = workflow_names
                .get(workflow_id)
                .cloned()
                .unwrap_or_else(|| workflow_id.0.to_string());
            format!("Sign workflow {workflow_name}")
        }
        ApprovalAction::RunCommand { tool, command } => {
            format!("Use {tool}: {command}")
        }
    }
}
