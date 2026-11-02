use crate::approval::{ApprovalAction, ApprovalPolicy};

#[must_use]
pub fn needs_approval(
    approval_policy: ApprovalPolicy,
    action: &ApprovalAction,
) -> bool {
    let is_workflow_signing =
        matches!(action, ApprovalAction::SignWorkflow { .. });
    let asks_before_risky_actions =
        approval_policy == ApprovalPolicy::AskBeforeRiskyActions;
    is_workflow_signing || asks_before_risky_actions
}
