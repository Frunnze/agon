use crate::approval::ApprovalPolicy;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ApprovalLevels {
    pub step: Option<ApprovalPolicy>,
    pub project: Option<ApprovalPolicy>,
    pub workspace: ApprovalPolicy,
}

#[must_use]
pub fn resolve_approval_policy(levels: ApprovalLevels) -> ApprovalPolicy {
    let closest_choice = levels.step.or(levels.project);
    closest_choice.unwrap_or(levels.workspace)
}
