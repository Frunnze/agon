use serde::Deserialize;
use serde_json::Value;

use super::chosen_folders::list_folder_paths;
use super::context_lines::{
    describe_project, describe_runner, describe_skill, describe_workflow,
    render_section,
};
use super::draft_kind::DraftKind;
use super::drafting_context::DraftingContext;
use super::format_instructions::render_format_instructions;
use super::item_draft::RepositoryDraft;
use crate::node_error::NodeError;

const CHOSEN_FOLDERS_HEADING: &str =
    "Folders the person chose on this computer (repos of this project)";

#[derive(Clone, Debug, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DraftChange {
    pub draft: Value,
    pub note: String,
}

pub fn render_drafting_prompt(
    context: &DraftingContext,
    kind: DraftKind,
    request: &str,
    started_from: Option<&str>,
    change: Option<&DraftChange>,
    chosen_folders: &[RepositoryDraft],
) -> Result<String, NodeError> {
    let mut parts = vec![
        format!("Draft a new {}.", kind.name()),
        kind.explanation().to_owned(),
        render_drafting_context(context),
    ];
    if let Some(started_from) = started_from {
        parts.push(format!("Started from: {started_from}"));
    }
    parts.push(format!("What the person wants:\n{request}"));
    if !chosen_folders.is_empty() {
        let paths = list_folder_paths(chosen_folders)?;
        parts.push(render_section(CHOSEN_FOLDERS_HEADING, &paths));
    }
    if let Some(change) = change {
        let current_draft = serde_json::to_string_pretty(&change.draft)?;
        parts.push(format!("Current draft:\n{current_draft}"));
        parts.push(format!("Requested change:\n{}", change.note));
    }
    let request_part = parts.join("\n");
    let instructions = render_format_instructions(kind);
    Ok(format!("{request_part}\n\n{instructions}"))
}

#[must_use]
pub fn render_drafting_context(context: &DraftingContext) -> String {
    let workspace = &context.workspace;
    let this_device = &context.this_device;
    let projects: Vec<String> =
        context.projects.iter().map(describe_project).collect();
    let workflows: Vec<String> =
        context.workflows.iter().map(describe_workflow).collect();
    let skills: Vec<String> =
        context.skills.iter().map(describe_skill).collect();
    let runners: Vec<String> =
        context.runners.iter().map(describe_runner).collect();
    let lines = [
        format!("Workspace: {} (id {})", workspace.name, workspace.id.0),
        format!(
            "This computer: {} (id {})",
            this_device.name, this_device.id.0
        ),
        render_section("Projects", &projects),
        render_section("Workflows", &workflows),
        render_section("Skills", &skills),
        render_section("Runners", &runners),
    ];
    lines.join("\n")
}
