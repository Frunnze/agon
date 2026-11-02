use std::fs;
use std::time::Duration;

use orchestration_runner::runner_server::RunnerServer;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::{
    PreparedWorkspace, create_task_command, prepare_workspace,
};
use crate::support::git_origin::LOCAL_REPOSITORY_ADDRESS;
use crate::support::runner_access::{
    open_runner, sample_heartbeat, started_task_command, test_runtime,
};
use crate::support::test_device::{describe, fail, read_text};
use crate::support::two_nodes::{TwoNodes, start_two_nodes_or_panic};
use crate::support::waiting::wait_for;

const TOGGLE_CASES: u32 = 4;
const MOST_TOGGLES: usize = 5;
const FLOW_LIMIT: Duration = Duration::from_secs(120);
const FAIL_ONCE_DETAILS: &str = "Fail once and then plan the change";
const FAILED_FOLDER_RECORD: &str = "failed-folder";
const RETRIED_FOLDER_RECORD: &str = "retried-folder";

fn prepared_or_panic() -> PreparedWorkspace {
    match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is prepared: {message}"),
    }
}

fn read_this_device_id(prepared: &PreparedWorkspace) -> Result<Value, String> {
    let status = prepared.device.run(&json!({ "command": "status" }))?;
    Ok(status["device_id"].clone())
}

fn switch_runner(
    prepared: &PreparedWorkspace,
    command_name: &str,
    device_id: &Value,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": command_name,
        "device_id": device_id,
    }))
}

fn read_accepting(prepared: &PreparedWorkspace) -> Result<Value, String> {
    let runners = prepared.device.run(&json!({
        "command": "list_runners",
        "workspace_id": prepared.workspace_id,
    }))?;
    Ok(runners["runners"][0]["runner"]["accepting_new_runs"].clone())
}

fn show_run(nodes: &TwoNodes, run_id: &str) -> Result<Value, String> {
    nodes
        .client
        .run(&json!({ "command": "show_run", "run_id": run_id }))
}

fn wait_for_run_status(
    nodes: &TwoNodes,
    run_id: &str,
    wanted_status: &str,
) -> Result<Value, String> {
    let description = format!("the run to be {wanted_status}");
    wait_for(FLOW_LIMIT, &description, || {
        let shown = show_run(nodes, run_id)?;
        let has_status = shown["run"]["status"] == wanted_status;
        Ok(has_status.then_some(shown))
    })
}

fn start_failing_task(nodes: &TwoNodes) -> Result<(String, String), String> {
    let project = nodes.client.run(&json!({
        "command": "create_project",
        "workspace_id": nodes.workspace_id,
        "name": "acme-app",
        "repositories": [{
            "address": LOCAL_REPOSITORY_ADDRESS,
            "default_branch": "main",
            "agent_access": "push_after_approval",
        }],
    }))?;
    let project_id = read_text(&project, "/id")?;
    let mut task = create_task_command(
        &nodes.workspace_id,
        &project_id,
        FAIL_ONCE_DETAILS,
    );
    task["start"] = json!("now");
    let created = nodes.client.run(&task)?;
    let task_id = read_text(&created, "/id")?;
    let runs = nodes.client.run(&json!({
        "command": "list_runs",
        "task_id": task_id,
    }))?;
    Ok((task_id, read_text(&runs, "/0/id")?))
}

fn read_record(nodes: &TwoNodes, name: &str) -> Result<String, String> {
    fs::read_to_string(nodes.records.path().join(name)).map_err(describe)
}

#[test]
fn test_resume_runner_property_the_last_switch_wins() {
    let prepared = prepared_or_panic();
    let Ok(runtime) = test_runtime() else {
        panic!("the test runtime starts");
    };
    let Ok(runner) = open_runner(&prepared) else {
        panic!("the runner side opens");
    };
    let sent = runtime.block_on(runner.send_heartbeat(&sample_heartbeat()));
    assert!(sent.is_ok(), "{sent:?}");
    let Ok(device_id) = read_this_device_id(&prepared) else {
        panic!("the device id is known");
    };
    let mut test_runner = TestRunner::new(Config::with_cases(TOGGLE_CASES));
    let switch_sequences = vec(any::<bool>(), 1..MOST_TOGGLES);

    let outcome = test_runner.run(&switch_sequences, |switches| {
        for should_accept in &switches {
            let command_name = if *should_accept {
                "resume_runner"
            } else {
                "pause_runner"
            };
            let switch_reply =
                switch_runner(&prepared, command_name, &device_id);
            prop_assert_eq!(switch_reply, Ok(Value::Null));
        }

        let accepting = read_accepting(&prepared).map_err(fail)?;

        let last_switch = switches.last().copied().unwrap_or_default();
        prop_assert_eq!(accepting, json!(last_switch));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn resume_runner_after_pause_runner_hands_out_work_again() {
    let prepared = prepared_or_panic();
    let Ok(runtime) = test_runtime() else {
        panic!("the test runtime starts");
    };
    let Ok(runner) = open_runner(&prepared) else {
        panic!("the runner side opens");
    };
    let Ok(device_id) = read_this_device_id(&prepared) else {
        panic!("the device id is known");
    };
    let sent = runtime.block_on(runner.send_heartbeat(&sample_heartbeat()));
    assert!(sent.is_ok(), "{sent:?}");
    let paused = switch_runner(&prepared, "pause_runner", &device_id);
    let task = prepared
        .device
        .run(&started_task_command(&prepared, "paused details"));
    assert!(task.is_ok(), "{task:?}");
    let while_paused = runtime.block_on(runner.claim_next_run());

    let resumed = switch_runner(&prepared, "resume_runner", &device_id);
    let accepting = read_accepting(&prepared);
    let after_resuming = runtime.block_on(runner.claim_next_run());

    assert_eq!(paused, Ok(Value::Null));
    assert_eq!(resumed, Ok(Value::Null));
    assert_eq!(accepting, Ok(json!(true)));
    let (Ok(while_paused), Ok(after_resuming)) =
        (while_paused, after_resuming)
    else {
        panic!("both claims are answered");
    };
    assert!(while_paused.assignment.is_none());
    assert!(after_resuming.assignment.is_some());
}

#[test]
fn retry_run_runs_the_failed_step_again_in_the_same_worktree() {
    let nodes = start_two_nodes_or_panic();
    let started = start_failing_task(&nodes);
    let Ok((task_id, run_id)) = started else {
        panic!("the task starts: {started:?}");
    };
    let failed = wait_for_run_status(&nodes, &run_id, "failed");
    let Ok(failed) = failed else {
        panic!("the run fails first: {failed:?}");
    };

    let retried = nodes
        .client
        .run(&json!({ "command": "retry_run", "run_id": run_id }));
    let finished = wait_for_run_status(&nodes, &run_id, "done");
    let runs = nodes
        .client
        .run(&json!({ "command": "list_runs", "task_id": task_id }));

    assert_eq!(retried, Ok(Value::Null));
    let Ok(finished) = finished else {
        panic!("the retried run finishes: {finished:?}");
    };
    let branch = &failed["run"]["worktree_branch"];
    assert!(branch.is_string(), "{failed}");
    assert_eq!(&finished["run"]["worktree_branch"], branch);
    let failed_folder = read_record(&nodes, FAILED_FOLDER_RECORD);
    let retried_folder = read_record(&nodes, RETRIED_FOLDER_RECORD);
    assert!(failed_folder.is_ok(), "{failed_folder:?}");
    assert_eq!(failed_folder, retried_folder);
    let Ok(runs) = runs else {
        panic!("the runs are listed: {runs:?}");
    };
    assert_eq!(runs.as_array().map(Vec::len), Some(1));
    assert_eq!(runs[0]["id"], json!(run_id));
}
