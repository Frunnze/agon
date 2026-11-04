use serde_json::{Value, json};

use crate::support::command_builders::two_step_workflow_command;
use crate::support::drafting_desk::{
    draft_command, finish_or_panic, open_desk_or_panic, start_or_panic,
};
use crate::support::test_device::read_text;

const PLAN_STEP_ID: &str = "00000000-0000-0000-0000-000000000031";
const BUILD_STEP_ID: &str = "00000000-0000-0000-0000-000000000032";
const CHECK_STEP_ID: &str = "00000000-0000-0000-0000-000000000033";
const DRAFTED_NAME: &str = "forked-pipeline";
const STEP_TASK: &str = "Do this step well";

fn drafted_step(agent_id: &str, name: &str) -> Value {
    json!({
        "id": agent_id,
        "name": name,
        "kind": "claude_code",
        "task": STEP_TASK,
        "runs_on": { "kind": "any_free_runner" },
        "skills": [],
        "uses_automatic_skills": false,
        "approval_policy": "never_ask",
        "position": { "horizontal": 40.0, "vertical": 16.0 },
    })
}

fn drafted_fork_json(workflow_id: &str) -> String {
    json!({
        "id": workflow_id,
        "name": DRAFTED_NAME,
        "availability": { "kind": "all_workspaces" },
        "agents": [
            drafted_step(PLAN_STEP_ID, "plan"),
            drafted_step(BUILD_STEP_ID, "build"),
            drafted_step(CHECK_STEP_ID, "check"),
        ],
        "connections": [
            { "from": PLAN_STEP_ID, "to": BUILD_STEP_ID },
            { "from": PLAN_STEP_ID, "to": CHECK_STEP_ID },
        ],
        "signature": null,
    })
    .to_string()
}

fn find_saved_step(view: &Value, step_name: &str) -> Value {
    let agents = view["workflow"]["agents"].as_array();
    let saved_agents = agents.map(Vec::as_slice).unwrap_or_default();
    let found = saved_agents.iter().find(|agent| agent["name"] == step_name);
    found.cloned().unwrap_or_default()
}

fn find_saved_position(view: &Value, step_name: &str) -> Value {
    find_saved_step(view, step_name)["position"].clone()
}

fn canvas_position(horizontal: f64, vertical: f64) -> Value {
    json!({ "horizontal": horizontal, "vertical": vertical })
}

fn assert_fork_laid_out(view: &Value) {
    let plan = find_saved_position(view, "plan");
    let build = find_saved_position(view, "build");
    let check = find_saved_position(view, "check");
    assert_eq!(plan, canvas_position(104.0, 0.0), "{view}");
    assert_eq!(build, canvas_position(0.0, 152.0), "{view}");
    assert_eq!(check, canvas_position(208.0, 152.0), "{view}");
}

fn assert_kept_steps_keep_their_ids(created: &Value, changed: &Value) {
    for kept_name in ["plan", "build"] {
        let created_id = &find_saved_step(created, kept_name)["id"];
        let changed_id = &find_saved_step(changed, kept_name)["id"];
        assert_eq!(created_id, changed_id, "{changed}");
    }
    let new_id = &find_saved_step(changed, "check")["id"];
    assert_ne!(new_id, &find_saved_step(created, "plan")["id"], "{changed}");
    assert_ne!(
        new_id,
        &find_saved_step(created, "build")["id"],
        "{changed}"
    );

    let connections = changed["workflow"]["connections"].clone();
    let plan_id = &find_saved_step(changed, "plan")["id"];
    let build_id = &find_saved_step(changed, "build")["id"];
    let expected = json!([
        { "from": plan_id, "to": build_id },
        { "from": plan_id, "to": new_id },
    ]);
    assert_eq!(read_joined_pairs(&connections), expected, "{changed}");
}

fn read_joined_pairs(connections: &Value) -> Value {
    let listed = connections.as_array().map(Vec::as_slice);
    let mut pairs = Vec::new();
    for connection in listed.unwrap_or_default() {
        pairs.push(json!({
            "from": connection["from"],
            "to": connection["to"],
        }));
    }
    Value::Array(pairs)
}

#[test]
fn a_drafted_workflow_is_saved_with_its_steps_laid_out_in_rows() {
    let desk = open_desk_or_panic();
    let draft = start_or_panic(&desk, &draft_command(&desk.prepared));
    finish_or_panic(&desk, &draft, &drafted_fork_json(&draft.workflow_id));

    let status = desk.status_reply(&draft);

    assert_eq!(status["ok"]["state"], "done", "{status}");
    assert_fork_laid_out(&status["ok"]["workflow"]);
}

#[test]
fn a_workflow_changed_by_the_agent_is_saved_laid_out() {
    let desk = open_desk_or_panic();
    let workspace_id = desk.prepared.workspace_id.clone();
    let created = desk.prepared.device.run(&two_step_workflow_command(
        &workspace_id,
        STEP_TASK,
        STEP_TASK,
    ));
    let Ok(created_view) = created else {
        panic!("the workflow is created");
    };
    let Ok(workflow_id) = read_text(&created_view, "/workflow/id") else {
        panic!("the created workflow has an id");
    };
    let change = json!({
        "command": "change_workflow",
        "workspace_id": workspace_id,
        "workflow_id": workflow_id,
        "request": "Check the plan while building it",
    });
    let draft = start_or_panic(&desk, &change);
    finish_or_panic(&desk, &draft, &drafted_fork_json(&workflow_id));

    let status = desk.status_reply(&draft);

    assert_eq!(status["ok"]["state"], "done", "{status}");
    assert_fork_laid_out(&status["ok"]["workflow"]);
    assert_kept_steps_keep_their_ids(&created_view, &status["ok"]["workflow"]);
}

#[test]
fn a_workflow_saved_by_hand_keeps_the_persons_positions() {
    let desk = open_desk_or_panic();
    let workspace_id = desk.prepared.workspace_id.clone();

    let created = desk.prepared.device.run(&two_step_workflow_command(
        &workspace_id,
        STEP_TASK,
        STEP_TASK,
    ));

    let Ok(view) = created else {
        panic!("the workflow is created");
    };
    let saved_agents = view["workflow"]["agents"].as_array();
    let saved_agents = saved_agents.map(Vec::as_slice).unwrap_or_default();
    assert_eq!(saved_agents.len(), 2, "{view}");
    for agent in saved_agents {
        assert_eq!(agent["position"], canvas_position(0.0, 0.0), "{view}");
    }
}
