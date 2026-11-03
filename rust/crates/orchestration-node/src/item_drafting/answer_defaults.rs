use orchestration_core::agent_place::AgentPlace;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::RunnerTarget;
use orchestration_core::task::TaskDoer;
use orchestration_core::workflow::AgentKind;
use orchestration_core::workspace::AgentAccess;

pub(super) const fn pick_form_doer() -> TaskDoer {
    TaskDoer::OneAgent {
        agent: AgentKind::ClaudeCode,
    }
}

pub(super) const fn pick_form_runner_target() -> RunnerTarget {
    RunnerTarget::AnyFreeRunner
}

pub(super) const fn pick_form_agent_place() -> AgentPlace {
    AgentPlace::LocalProcess
}

pub(super) const fn pick_form_automatic_skills_choice() -> bool {
    true
}

pub(super) const fn pick_form_approval_policy() -> ApprovalPolicy {
    ApprovalPolicy::AskBeforeRiskyActions
}

pub(super) const fn pick_form_agent_access() -> AgentAccess {
    AgentAccess::PushAfterApproval
}
