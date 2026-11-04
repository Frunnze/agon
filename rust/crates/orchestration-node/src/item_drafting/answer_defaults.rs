use orchestration_core::agent_place::AgentPlace;
use orchestration_core::device::RunnerTarget;
use orchestration_core::library::SkillImprovement;
use orchestration_core::naming::convert_to_project_name;
use orchestration_core::task::TaskDoer;
use orchestration_core::workflow::AgentKind;
use orchestration_core::workspace::AgentAccess;

use super::item_draft::RepositoryDraft;

const ADDRESS_PART_SEPARATORS: [char; 2] = ['/', '\\'];

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

pub(super) const fn pick_form_skill_improvement() -> SkillImprovement {
    SkillImprovement::Auto
}

pub(super) const fn pick_form_agent_access() -> AgentAccess {
    AgentAccess::PushAfterApproval
}

pub(super) fn pick_form_project_name(
    answered_name: &str,
    repositories: &[RepositoryDraft],
) -> String {
    let trimmed_name = answered_name.trim();
    if !trimmed_name.is_empty() {
        return trimmed_name.to_owned();
    }
    let Some(first_repository) = repositories.first() else {
        return String::new();
    };

    let last_address_part = first_repository
        .address
        .rsplit(ADDRESS_PART_SEPARATORS)
        .next()
        .unwrap_or_default();
    convert_to_project_name(last_address_part)
}
