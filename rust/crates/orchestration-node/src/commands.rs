mod account_commands;
mod agent_login_commands;
#[cfg(feature = "runner")]
mod agent_login_status;
mod agent_place_commands;
mod approval_commands;
mod code_joining;
mod deletion_commands;
mod device_commands;
mod device_forgetting;
mod device_registration;
mod drafting_context_reading;
mod file_commands;
mod file_holders;
mod folder_git_start;
mod hosted_account;
mod item_draft_commands;
mod join_status;
mod library_commands;
mod library_edits;
mod live_commands;
pub(crate) mod local_folder_checks;
mod pairing_approval;
mod pairing_commands;
mod person_answers;
mod project_commands;
mod repository_sources;
mod run_commands;
mod runner_commands;
mod server_backup_commands;
mod shown_words;
mod skill_change_view;
mod task_commands;
mod task_views;
mod workflow_agent_commands;
mod workflow_agent_prompts;
mod workflow_commands;
mod workflow_drafts;
mod workflow_skill_removal;
mod workflow_view;

use serde::de::DeserializeOwned;
use serde_json::Value;

use crate::command_reply::render_reply;
use crate::node::Node;
use crate::node_error::NodeError;

const COMMAND_FIELD: &str = "command";

#[derive(Clone, Copy, Debug)]
enum CommandArea {
    Account,
    Pairing,
    Device,
    Project,
    Library,
    LibraryEdit,
    Workflow,
    WorkflowAgent,
    WorkflowDraft,
    ItemDraft,
    Task,
    Run,
    Live,
    File,
    Approval,
    Runner,
    AgentPlace,
    AgentLogin,
    ServerBackup,
    Deletion,
}

const COMMAND_AREAS: [(CommandArea, &[&str]); 20] = [
    (
        CommandArea::Account,
        &account_commands::ACCOUNT_COMMAND_NAMES,
    ),
    (
        CommandArea::Pairing,
        &pairing_commands::PAIRING_COMMAND_NAMES,
    ),
    (CommandArea::Device, &device_commands::DEVICE_COMMAND_NAMES),
    (
        CommandArea::Project,
        &project_commands::PROJECT_COMMAND_NAMES,
    ),
    (
        CommandArea::Library,
        &library_commands::LIBRARY_COMMAND_NAMES,
    ),
    (
        CommandArea::LibraryEdit,
        &library_edits::LIBRARY_EDIT_COMMAND_NAMES,
    ),
    (
        CommandArea::Workflow,
        &workflow_commands::WORKFLOW_COMMAND_NAMES,
    ),
    (
        CommandArea::WorkflowAgent,
        &workflow_agent_commands::WORKFLOW_AGENT_COMMAND_NAMES,
    ),
    (
        CommandArea::WorkflowDraft,
        &workflow_drafts::WORKFLOW_DRAFT_COMMAND_NAMES,
    ),
    (
        CommandArea::ItemDraft,
        &item_draft_commands::ITEM_DRAFT_COMMAND_NAMES,
    ),
    (CommandArea::Task, &task_commands::TASK_COMMAND_NAMES),
    (CommandArea::Run, &run_commands::RUN_COMMAND_NAMES),
    (CommandArea::Live, &live_commands::LIVE_COMMAND_NAMES),
    (CommandArea::File, &file_commands::FILE_COMMAND_NAMES),
    (
        CommandArea::Approval,
        &approval_commands::APPROVAL_COMMAND_NAMES,
    ),
    (CommandArea::Runner, &runner_commands::RUNNER_COMMAND_NAMES),
    (
        CommandArea::AgentPlace,
        &agent_place_commands::AGENT_PLACE_COMMAND_NAMES,
    ),
    (
        CommandArea::AgentLogin,
        &agent_login_commands::AGENT_LOGIN_COMMAND_NAMES,
    ),
    (
        CommandArea::ServerBackup,
        &server_backup_commands::SERVER_BACKUP_COMMAND_NAMES,
    ),
    (
        CommandArea::Deletion,
        &deletion_commands::DELETION_COMMAND_NAMES,
    ),
];

#[must_use]
pub fn command_names() -> Vec<&'static str> {
    let mut names = Vec::new();
    for (_, area_names) in COMMAND_AREAS {
        names.extend_from_slice(area_names);
    }
    names
}

pub async fn dispatch_command(node: &Node, command_json: &str) -> String {
    let outcome = run_command(node, command_json).await;
    render_reply(&outcome)
}

async fn run_command(
    node: &Node,
    command_json: &str,
) -> Result<Value, NodeError> {
    let command: Value = serde_json::from_str(command_json)
        .map_err(|error| NodeError::InvalidCommand(error.to_string()))?;
    let name = read_command_name(&command)?;
    let area = find_command_area(&name)?;

    match area {
        CommandArea::Account => {
            let parsed = parse_command(&name, command)?;
            account_commands::handle_account_command(node, parsed).await
        }
        CommandArea::Pairing => {
            let parsed = parse_command(&name, command)?;
            pairing_commands::handle_pairing_command(node, parsed).await
        }
        CommandArea::Device => {
            let parsed = parse_command(&name, command)?;
            device_commands::handle_device_command(node, parsed).await
        }
        CommandArea::Project => {
            let parsed = parse_command(&name, command)?;
            project_commands::handle_project_command(node, parsed).await
        }
        CommandArea::Library => {
            let parsed = parse_command(&name, command)?;
            library_commands::handle_library_command(node, parsed).await
        }
        CommandArea::LibraryEdit => {
            let parsed = parse_command(&name, command)?;
            library_edits::handle_library_edit_command(node, parsed).await
        }
        CommandArea::Workflow => {
            let parsed = parse_command(&name, command)?;
            workflow_commands::handle_workflow_command(node, parsed).await
        }
        CommandArea::WorkflowAgent => {
            let parsed = parse_command(&name, command)?;
            workflow_agent_commands::handle_workflow_agent_command(
                node, parsed,
            )
            .await
        }
        CommandArea::WorkflowDraft => {
            let parsed = parse_command(&name, command)?;
            workflow_drafts::handle_workflow_draft_command(node, parsed).await
        }
        CommandArea::ItemDraft => {
            let parsed = parse_command(&name, command)?;
            item_draft_commands::handle_item_draft_command(node, parsed).await
        }
        CommandArea::Task => {
            let parsed = parse_command(&name, command)?;
            task_commands::handle_task_command(node, parsed).await
        }
        CommandArea::Run => {
            let parsed = parse_command(&name, command)?;
            run_commands::handle_run_command(node, parsed).await
        }
        CommandArea::Live => {
            let parsed = parse_command(&name, command)?;
            live_commands::handle_live_command(node, parsed).await
        }
        CommandArea::File => {
            let parsed = parse_command(&name, command)?;
            file_commands::handle_file_command(node, parsed).await
        }
        CommandArea::Approval => {
            let parsed = parse_command(&name, command)?;
            approval_commands::handle_approval_command(node, parsed).await
        }
        CommandArea::Runner => {
            let parsed = parse_command(&name, command)?;
            runner_commands::handle_runner_command(node, parsed).await
        }
        CommandArea::AgentPlace => {
            let parsed = parse_command(&name, command)?;
            agent_place_commands::handle_agent_place_command(node, &parsed)
        }
        CommandArea::AgentLogin => {
            let parsed = parse_command(&name, command)?;
            agent_login_commands::handle_agent_login_command(node, parsed)
                .await
        }
        CommandArea::ServerBackup => {
            let parsed = parse_command(&name, command)?;
            server_backup_commands::handle_server_backup_command(node, parsed)
                .await
        }
        CommandArea::Deletion => {
            let parsed = parse_command(&name, command)?;
            deletion_commands::handle_deletion_command(node, parsed).await
        }
    }
}

fn read_command_name(command: &Value) -> Result<String, NodeError> {
    let name = command.get(COMMAND_FIELD).and_then(Value::as_str);
    let Some(name) = name else {
        return Err(NodeError::InvalidCommand(format!(
            "the {COMMAND_FIELD} field is missing or not text"
        )));
    };
    Ok(name.to_owned())
}

fn find_command_area(name: &str) -> Result<CommandArea, NodeError> {
    for (area, area_names) in COMMAND_AREAS {
        if area_names.contains(&name) {
            return Ok(area);
        }
    }
    Err(NodeError::UnknownCommand(name.to_owned()))
}

fn parse_command<Command: DeserializeOwned>(
    name: &str,
    command: Value,
) -> Result<Command, NodeError> {
    serde_json::from_value(command).map_err(|error| {
        NodeError::InvalidArguments {
            command: name.to_owned(),
            problem: error.to_string(),
        }
    })
}
