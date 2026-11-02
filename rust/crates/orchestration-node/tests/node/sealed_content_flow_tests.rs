use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::command_builders::{
    PreparedWorkspace, create_rule_command, create_skill_command,
    create_task_command, create_workflow_command, prepare_workspace,
};
use crate::support::entity_strategies::secret_text_strategy;
use crate::support::test_device::{fail, read_text};

const FLOW_CASES: u32 = 6;
const SUCCESS_STATUS_START: u16 = 200;
const SUCCESS_STATUS_END: u16 = 300;

#[derive(Debug)]
struct Secrets {
    task_details: String,
    skill_instructions: String,
    rule_details: String,
    agent_task: String,
    chat_text: String,
}

fn secrets_strategy() -> impl Strategy<Value = Secrets> {
    (
        secret_text_strategy(),
        secret_text_strategy(),
        secret_text_strategy(),
        secret_text_strategy(),
        secret_text_strategy(),
    )
        .prop_map(build_secrets)
}

fn build_secrets(texts: (String, String, String, String, String)) -> Secrets {
    let (
        task_details,
        skill_instructions,
        rule_details,
        agent_task,
        chat_text,
    ) = texts;
    Secrets {
        task_details,
        skill_instructions,
        rule_details,
        agent_task,
        chat_text,
    }
}

fn upload_secrets(
    prepared: &PreparedWorkspace,
    secrets: &Secrets,
) -> Result<(), String> {
    let device = &prepared.device;
    let workspace_id = &prepared.workspace_id;
    let task = device.run(&create_task_command(
        workspace_id,
        &prepared.project_id,
        &secrets.task_details,
    ))?;
    let task_id = read_text(&task, "/id")?;
    device.run(&create_skill_command(
        workspace_id,
        &secrets.skill_instructions,
    ))?;
    device.run(&create_rule_command(workspace_id, &secrets.rule_details))?;
    let workflow = device
        .run(&create_workflow_command(workspace_id, &secrets.agent_task))?;
    let workflow_id = read_text(&workflow, "/workflow/id")?;
    device.run(&json!({
        "command": "sign_workflow",
        "workflow_id": workflow_id,
    }))?;
    let run =
        device.run(&json!({ "command": "start_task", "task_id": task_id }))?;
    let run_id = read_text(&run, "/id")?;
    device.run(&json!({
        "command": "send_chat_message",
        "workspace_id": workspace_id,
        "run_id": run_id,
        "text": secrets.chat_text,
    }))?;
    Ok(())
}

fn list_everything(prepared: &PreparedWorkspace) -> Result<String, String> {
    let device = &prepared.device;
    let workspace_id = &prepared.workspace_id;
    let mut listings = Vec::new();
    for command_name in
        ["list_tasks", "list_skills", "list_rules", "list_workflows"]
    {
        let listing = device.run(&json!({
            "command": command_name,
            "workspace_id": workspace_id,
        }))?;
        listings.push(listing);
    }
    let tasks = &listings[0];
    let task_id = read_text(tasks, "/tasks/0/task/id")?;
    let runs =
        device.run(&json!({ "command": "list_runs", "task_id": task_id }))?;
    listings.push(runs);
    Ok(Value::Array(listings).to_string())
}

#[test]
fn the_server_accepts_every_signed_request() {
    let prepared = prepare_workspace();

    let Ok(prepared) = prepared else {
        panic!("the workspace is prepared: {prepared:?}");
    };
    let requests = prepared.server.recorded_requests();
    assert!(!requests.is_empty());
    for request in requests {
        assert!(
            is_success(request.status),
            "{} {}",
            request.path,
            request.status
        );
    }
}

fn is_success(status: u16) -> bool {
    (SUCCESS_STATUS_START..SUCCESS_STATUS_END).contains(&status)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FLOW_CASES))]

    #[test]
    fn test_dispatch_command_property_server_never_sees_sealed_plaintext(
        secrets in secrets_strategy(),
    ) {
        let prepared = prepare_workspace().map_err(fail)?;

        upload_secrets(&prepared, &secrets).map_err(fail)?;

        let every_secret = [
            &secrets.task_details,
            &secrets.skill_instructions,
            &secrets.rule_details,
            &secrets.agent_task,
            &secrets.chat_text,
        ];
        let stored_state = prepared.server.read_stored_state().map_err(fail)?;
        for request in prepared.server.recorded_requests() {
            prop_assert!(is_success(request.status), "{}", request.path);
            let body_text = String::from_utf8_lossy(&request.body);
            for secret in every_secret {
                prop_assert!(!body_text.contains(secret.as_str()));
                prop_assert!(!stored_state.contains(secret.as_str()));
            }
        }
        let listings = list_everything(&prepared).map_err(fail)?;
        for secret in every_secret {
            let is_listed = listings.contains(secret.as_str());
            prop_assert!(is_listed, "{secret} missing");
        }
    }
}
