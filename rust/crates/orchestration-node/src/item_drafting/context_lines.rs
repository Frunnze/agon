use orchestration_core::library::SkillUsage;
use orchestration_core::workspace::Project;

use super::drafting_context::{
    DraftingRunner, DraftingSkill, DraftingWorkflow,
};

const LIST_SEPARATOR: &str = ", ";
const EMPTY_SECTION_LINE: &str = "- none";

pub(super) fn render_section(heading: &str, entries: &[String]) -> String {
    let mut lines = vec![format!("{heading}:")];
    if entries.is_empty() {
        lines.push(EMPTY_SECTION_LINE.to_owned());
    }
    for entry in entries {
        lines.push(format!("- {entry}"));
    }
    lines.join("\n")
}

pub(super) fn describe_project(project: &Project) -> String {
    let named = format!("{} (id {})", project.name, project.id.0);
    let addresses: Vec<&str> = project
        .repositories
        .iter()
        .map(|repository| repository.address.as_str())
        .collect();
    if addresses.is_empty() {
        return named;
    }
    format!("{named}: {}", addresses.join(LIST_SEPARATOR))
}

pub(super) fn describe_workflow(workflow: &DraftingWorkflow) -> String {
    let signature_state = if workflow.is_signed {
        "signed"
    } else {
        "not signed yet"
    };
    format!(
        "{} (id {}), {signature_state}",
        workflow.name, workflow.id.0
    )
}

pub(super) fn describe_skill(skill: &DraftingSkill) -> String {
    let usage = match skill.usage {
        SkillUsage::Automatic => "automatic",
        SkillUsage::WhenChosen => "when chosen",
    };
    format!(
        "{} (id {}), {usage}: {}",
        skill.name, skill.id.0, skill.summary
    )
}

pub(super) fn describe_runner(runner: &DraftingRunner) -> String {
    let presence = if runner.is_online {
        "online"
    } else {
        "offline"
    };
    let named = format!(
        "{} (id {}), {presence}",
        runner.device.name, runner.device.id.0
    );
    if runner.labels.is_empty() {
        return named;
    }
    format!("{named}, labels: {}", runner.labels.join(LIST_SEPARATOR))
}
