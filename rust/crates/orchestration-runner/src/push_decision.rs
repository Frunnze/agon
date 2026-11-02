use orchestration_core::approval::{ApprovalAction, ApprovalPolicy};
use orchestration_core::approval_policy::needs_approval;
use orchestration_core::workspace::{AgentAccess, Repository};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum PushDecision {
    KeepLocal,
    PushNow,
    AskFirst(ApprovalAction),
}

#[must_use]
pub fn decide_push(
    approval_policy: ApprovalPolicy,
    repository: &Repository,
    branch: &str,
    unpushed_commits: &[String],
) -> PushDecision {
    let is_read_only = repository.agent_access == AgentAccess::ReadOnly;
    if unpushed_commits.is_empty() || is_read_only {
        return PushDecision::KeepLocal;
    }

    let action = ApprovalAction::PushCommits {
        repository: repository.address.clone(),
        branch: branch.to_string(),
        commits: unpushed_commits.to_vec(),
    };
    if needs_approval(approval_policy, &action) {
        return PushDecision::AskFirst(action);
    }
    PushDecision::PushNow
}
