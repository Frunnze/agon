use axum::http::StatusCode;
use orchestration_api::work::{
    AnswerPersonStepRequest, RunAssignment, RunEvent, RunEventsRequest,
    TaskStart,
};
use orchestration_core::device::RunnerTarget;
use orchestration_core::run::{Run, RunStep, StepStatus};
use orchestration_core::workflow::{
    AgentConnection, StepKind, Workflow, WorkflowAgent,
};
use orchestration_security::identity::DeviceIdentity;

use crate::claim_fixtures::{claim, pair_runners};
use crate::fixtures::{Account, create_account, create_project, save_task};
use crate::run_fixtures::run_path;
use crate::test_client::{TestResponse, TestServer};
use crate::workflow_fixtures::{
    create_signed_workflow, workflow_agent, workflow_task,
};

pub type PlannedConnection<'plan> =
    (usize, usize, Option<&'plan str>, Option<u32>);

#[derive(Debug)]
pub struct BranchingRun {
    pub account: Account,
    pub runners: Vec<DeviceIdentity>,
    pub run: Run,
}

pub fn branching_workflow(
    steps: &[(&str, StepKind)],
    connections: &[PlannedConnection<'_>],
) -> Workflow {
    let mut agents = Vec::new();
    for (name, step_kind) in steps {
        agents.push(WorkflowAgent {
            step_kind: *step_kind,
            ..workflow_agent(name, RunnerTarget::AnyFreeRunner)
        });
    }
    let mut planned_connections = Vec::new();
    for (from, to, condition, round_limit) in connections {
        planned_connections.push(AgentConnection {
            from: agents[*from].id,
            to: agents[*to].id,
            condition: condition.map(str::to_owned),
            round_limit: *round_limit,
        });
    }
    let base = crate::workflow_fixtures::workflow_with_connections(0, &[]);
    Workflow {
        agents,
        connections: planned_connections,
        ..base
    }
}

pub async fn start_branching_run(
    test: &TestServer,
    workflow: Workflow,
    runner_count: u8,
    slots_total: u32,
) -> BranchingRun {
    let account = create_account(test).await;
    let project = create_project(test, &account).await;
    let runners =
        pair_runners(test, &account, runner_count, slots_total).await;
    let workflow = create_signed_workflow(test, &account, workflow).await;
    let task = workflow_task(project.id, workflow.id);
    let saved = save_task(test, &account, task, TaskStart::Now).await;
    let run = saved.run.expect("the task starts a run");
    BranchingRun {
        account,
        runners,
        run,
    }
}

pub async fn claim_step(
    test: &TestServer,
    runner: &DeviceIdentity,
) -> Option<RunAssignment> {
    claim(test, runner).await.assignment
}

pub async fn finish_claimed_step(
    test: &TestServer,
    runner: &DeviceIdentity,
    assignment: &RunAssignment,
    outcome: Option<&str>,
) -> TestResponse {
    let step_name = assignment.step_name.clone();
    let events = vec![
        RunEvent::StepStatusChanged {
            step_name: step_name.clone(),
            status: StepStatus::Running,
        },
        RunEvent::StepResultRecorded {
            step_name: step_name.clone(),
            result: format!("result of {step_name}"),
            outcome: outcome.map(str::to_owned),
        },
        RunEvent::StepStatusChanged {
            step_name,
            status: StepStatus::Done,
        },
    ];
    let request = RunEventsRequest { events };
    let path = format!("/runs/{}/events", assignment.run.id.0);
    test.post(runner, &path, &request).await
}

pub async fn claim_and_finish(
    test: &TestServer,
    runner: &DeviceIdentity,
    expected_step: &str,
    outcome: Option<&str>,
) -> RunAssignment {
    let assignment = claim_step(test, runner).await;
    let assignment = assignment.expect("a step is ready");
    assert_eq!(assignment.step_name, expected_step);
    let finished =
        finish_claimed_step(test, runner, &assignment, outcome).await;
    assert_eq!(finished.status, StatusCode::OK);
    assignment
}

pub async fn read_run(test: &TestServer, account: &Account, run: &Run) -> Run {
    let response = test.get(&account.owner, &run_path(run)).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}

pub async fn answer_step(
    test: &TestServer,
    identity: &DeviceIdentity,
    run: &Run,
    step_name: &str,
    answer: &str,
) -> TestResponse {
    let path = format!("/runs/{}/steps/{step_name}/answer", run.id.0);
    let request = AnswerPersonStepRequest {
        answer: answer.to_owned(),
        choice: None,
    };
    test.post(identity, &path, &request).await
}

pub fn find_step<'run>(run: &'run Run, step_name: &str) -> &'run RunStep {
    run.steps
        .iter()
        .find(|step| step.name == step_name)
        .expect("the run has the step")
}
