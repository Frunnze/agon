use std::fs;

use axum::http::StatusCode;
use orchestration_api::work::{OpenPersonStep, RunEvent, RunEventsRequest};
use orchestration_core::run::{Run, RunFailure, StepStatus};
use orchestration_core::workflow::{StepKind, Workflow};
use orchestration_security::identity::DeviceIdentity;
use serde_json::Value;

use crate::branching_fixtures::{
    BranchingRun, branching_workflow, claim_and_finish, claim_step, read_run,
    start_branching_run,
};
use crate::test_client::{TestResponse, TestServer};

pub const QUESTION_STEP: &str = "ask";
pub const LOOP_ANSWER: &str = "again";
const RUNNER_SLOTS: u32 = 4;
const STATE_FILE_NAME: &str = "state.json";
const WAITING_FOR_PERSON: &str = "waiting_for_person";

#[derive(Debug)]
pub struct FailedQuestion {
    pub started: BranchingRun,
    pub failed: Run,
}

fn question_workflow() -> Workflow {
    branching_workflow(
        &[
            ("start", StepKind::Agent),
            (QUESTION_STEP, StepKind::Person),
            ("work", StepKind::Agent),
            ("ship", StepKind::Agent),
        ],
        &[
            (0, 1, None, None),
            (0, 2, None, None),
            (1, 3, Some("approved"), None),
            (1, 0, Some(LOOP_ANSWER), Some(1)),
        ],
    )
}

pub fn step_events(step_name: &str, statuses: &[StepStatus]) -> Vec<RunEvent> {
    let mut events = Vec::new();
    for status in statuses {
        events.push(RunEvent::StepStatusChanged {
            step_name: step_name.to_owned(),
            status: *status,
        });
    }
    events
}

pub fn failure_events(step_name: &str, reason: &str) -> Vec<RunEvent> {
    let mut events = step_events(step_name, &[StepStatus::Failed]);
    events.push(RunEvent::Failed {
        failure: RunFailure {
            step_name: step_name.to_owned(),
            runner: None,
            reason: reason.to_owned(),
            retry_runs_on_same_runner: false,
        },
    });
    events
}

pub async fn post_run_events(
    test: &TestServer,
    runner: &DeviceIdentity,
    run: &Run,
    events: Vec<RunEvent>,
) -> TestResponse {
    let request = RunEventsRequest { events };
    let path = format!("/runs/{}/events", run.id.0);
    test.post(runner, &path, &request).await
}

pub async fn reach_question(test: &TestServer) -> BranchingRun {
    let started =
        start_branching_run(test, question_workflow(), 1, RUNNER_SLOTS).await;
    claim_and_finish(test, &started.runners[0], "start", None).await;
    started
}

pub async fn fail_beside_question(
    test: &TestServer,
    reason: &str,
) -> FailedQuestion {
    let started = reach_question(test).await;
    let runner = &started.runners[0];
    let work = claim_step(test, runner).await.expect("work is ready");
    let mut events = step_events(&work.step_name, &[StepStatus::Running]);
    events.extend(failure_events(&work.step_name, reason));
    let response = post_run_events(test, runner, &work.run, events).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    let failed = read_run(test, &started.account, &started.run).await;
    FailedQuestion { started, failed }
}

pub const WORK_STATUSES: [StepStatus; 3] = [
    StepStatus::Waiting,
    StepStatus::Running,
    StepStatus::WaitingForApproval,
];

#[derive(Debug)]
pub struct CancelledRun {
    pub started: BranchingRun,
    pub before: Run,
    pub cancelled: Run,
}

pub async fn cancel_while_asking(
    test: &TestServer,
    work_status: StepStatus,
) -> CancelledRun {
    let started = reach_question(test).await;
    let runner = &started.runners[0];
    if work_status != StepStatus::Waiting {
        let work = claim_step(test, runner).await.expect("work is ready");
        let events = step_events(&work.step_name, &[work_status]);
        let response = post_run_events(test, runner, &work.run, events).await;
        assert_eq!(response.status, StatusCode::OK, "{response:?}");
    }
    let before = read_run(test, &started.account, &started.run).await;
    let owner = &started.account.owner;
    let response = cancel_run(test, owner, &started.run).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    let cancelled = response.json();
    CancelledRun {
        started,
        before,
        cancelled,
    }
}

pub async fn list_open_steps(
    test: &TestServer,
    owner: &DeviceIdentity,
) -> Vec<OpenPersonStep> {
    let response = test.get(owner, "/person-steps").await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}

pub async fn cancel_run(
    test: &TestServer,
    owner: &DeviceIdentity,
    run: &Run,
) -> TestResponse {
    let path = format!("/runs/{}/cancel", run.id.0);
    test.post_empty(owner, &path).await
}

fn reopen_question_in_state(state: &mut Value, run: &Run) {
    let run_key = run.id.0.to_string();
    let steps = &mut state["runs"][run_key.as_str()]["run"]["steps"];
    let Some(steps) = steps.as_array_mut() else {
        panic!("the stored run has steps");
    };
    for step in steps {
        if step["name"] == QUESTION_STEP {
            step["status"] = Value::from(WAITING_FOR_PERSON);
            step["finished_at"] = Value::Null;
        }
    }
}

pub fn restart_with_question_still_open(
    test: &TestServer,
    run: &Run,
) -> TestServer {
    let state_path = test.directory.path().join(STATE_FILE_NAME);
    let stored_text =
        fs::read_to_string(&state_path).expect("the state is saved");
    let mut state: Value =
        serde_json::from_str(&stored_text).expect("the state is JSON");
    reopen_question_in_state(&mut state, run);
    let changed_text =
        serde_json::to_string(&state).expect("the state encodes");
    fs::write(&state_path, changed_text).expect("the state is written");
    test.restart()
}
