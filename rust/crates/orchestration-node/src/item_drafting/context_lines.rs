use orchestration_core::agent_place::AgentPlace;
use orchestration_core::library::SkillUsage;
use orchestration_core::workspace::Project;

use super::drafting_context::{
    DraftingRunner, DraftingSkill, DraftingWorkflow,
};

const LIST_SEPARATOR: &str = ", ";
const EMPTY_SECTION_LINE: &str = "- none";
const LOCAL_OFFER_NAME: &str = "local_process";
const CONTAINER_OFFER_NAME: &str = "container";
const NO_OFFERS_TEXT: &str = "nothing";

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
        SkillUsage::WhenChosen => "when_chosen",
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
    let mut parts = vec![
        format!("{} (id {})", runner.device.name, runner.device.id.0),
        presence.to_owned(),
    ];
    if !runner.labels.is_empty() {
        let labels = runner.labels.join(LIST_SEPARATOR);
        parts.push(format!("labels: {labels}"));
    }
    parts.push(format!("offers: {}", describe_offers(runner)));
    parts.join(LIST_SEPARATOR)
}

fn describe_offers(runner: &DraftingRunner) -> String {
    let mut offer_names = Vec::new();
    for offer in &runner.offers {
        let offer_name = match offer {
            AgentPlace::LocalProcess => LOCAL_OFFER_NAME,
            AgentPlace::Container => CONTAINER_OFFER_NAME,
        };
        offer_names.push(offer_name);
    }
    if offer_names.is_empty() {
        return NO_OFFERS_TEXT.to_owned();
    }
    offer_names.join(LIST_SEPARATOR)
}
