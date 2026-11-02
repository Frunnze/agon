use orchestration_core::approval::{ApprovalAction, ApprovalDecision};

const SINGLE_COMMIT: usize = 1;

pub fn describe_request(action: &ApprovalAction) -> String {
    match action {
        ApprovalAction::PushCommits { commits, .. } => {
            format!("Asked to push {}", count_commits(commits.len()))
        }
        ApprovalAction::Deploy { target } => {
            format!("Asked to deploy to {target}")
        }
        ApprovalAction::DeleteBranchOrFiles { what, .. } => {
            format!("Asked to delete {what}")
        }
        ApprovalAction::SignWorkflow { .. } => {
            "Asked to sign a workflow".to_owned()
        }
    }
}

pub fn describe_decision(
    decision: ApprovalDecision,
    action: &ApprovalAction,
) -> String {
    let verb = match decision {
        ApprovalDecision::Approved => "Approved",
        ApprovalDecision::Denied => "Denied",
    };
    format!("{verb} {}", describe_action_in_progress(action))
}

fn describe_action_in_progress(action: &ApprovalAction) -> String {
    match action {
        ApprovalAction::PushCommits { commits, .. } => {
            format!("pushing {}", count_commits(commits.len()))
        }
        ApprovalAction::Deploy { target } => format!("deploying to {target}"),
        ApprovalAction::DeleteBranchOrFiles { what, .. } => {
            format!("deleting {what}")
        }
        ApprovalAction::SignWorkflow { .. } => "signing a workflow".to_owned(),
    }
}

fn count_commits(commit_count: usize) -> String {
    if commit_count == SINGLE_COMMIT {
        return format!("{commit_count} commit");
    }
    format!("{commit_count} commits")
}
