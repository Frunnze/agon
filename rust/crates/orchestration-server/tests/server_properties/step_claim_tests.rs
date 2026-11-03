use std::collections::BTreeSet;

use axum::http::StatusCode;
use orchestration_api::work::{RunAssignment, RunEvent, TaskStart};
use orchestration_core::run::StepStatus;
use orchestration_core::workflow_graph::upstream_agents;
use orchestration_security::identity::DeviceIdentity;
use proptest::prelude::*;

use crate::claim_fixtures::{claim, pair_runners};
use crate::fixtures::{create_account, create_project, save_task};
use crate::run_fixtures::post_events;
use crate::test_client::{TestServer, block_on};
use crate::workflow_fixtures::{
    create_signed_workflow, workflow_task, workflow_with_connections,
};

const MOST_AGENTS: usize = 4;
const MOST_RUNNERS: u8 = 3;
const MOST_ROUNDS: usize = 12;
const RUNNER_SLOTS: u32 = 8;
const FINISHING_ROUNDS_PER_AGENT: usize = 3;
const RECORDED_RESULT: &str = "sealed result of the first step";

type WorkflowShape = (usize, Vec<(usize, usize)>);
type ClaimRound = (usize, bool);

#[derive(Debug)]
struct GivenStep {
    step_name: String,
    is_held_by_claimer: bool,
    has_upstream_done: bool,
}

fn workflow_shape() -> impl Strategy<Value = WorkflowShape> {
    (2..=MOST_AGENTS).prop_flat_map(|agent_count| {
        let mut pairs = Vec::new();
        for from in 0..agent_count {
            for to in from + 1..agent_count {
                pairs.push((from, to));
            }
        }
        let pair_count = pairs.len();
        let chosen = proptest::sample::subsequence(pairs, 0..=pair_count);
        (Just(agent_count), chosen)
    })
}

fn has_upstream_done(assignment: &RunAssignment) -> bool {
    let Some(workflow) = &assignment.workflow else {
        return true;
    };
    let given_agent = workflow
        .agents
        .iter()
        .find(|agent| agent.name == assignment.step_name);
    let Some(given_agent) = given_agent else {
        return false;
    };
    upstream_agents(workflow, given_agent.id)
        .iter()
        .all(|upstream| {
            assignment.run.steps.iter().any(|step| {
                step.name == upstream.name && step.status == StepStatus::Done
            })
        })
}

fn describe_given_step(
    assignment: &RunAssignment,
    claimer: &DeviceIdentity,
) -> GivenStep {
    let claimer_id = claimer.device_id();
    let is_held_by_claimer = assignment.run.steps.iter().any(|step| {
        step.name == assignment.step_name
            && step.runner.as_ref() == Some(&claimer_id)
    });
    GivenStep {
        step_name: assignment.step_name.clone(),
        is_held_by_claimer,
        has_upstream_done: has_upstream_done(assignment),
    }
}

async fn finish_step(
    test: &TestServer,
    holder: &DeviceIdentity,
    assignment: &RunAssignment,
) {
    let step_name = assignment.step_name.clone();
    let events = vec![
        RunEvent::StepStatusChanged {
            step_name: step_name.clone(),
            status: StepStatus::Running,
        },
        RunEvent::StepStatusChanged {
            step_name,
            status: StepStatus::Done,
        },
    ];
    let (status, _run) =
        post_events(test, holder, &assignment.run, events).await;
    assert_eq!(status, StatusCode::OK);
}

async fn give_out_steps(
    test: &TestServer,
    runner_count: u8,
    shape: &WorkflowShape,
    rounds: Vec<ClaimRound>,
) -> Vec<GivenStep> {
    let account = create_account(test).await;
    let project = create_project(test, &account).await;
    let runners =
        pair_runners(test, &account, runner_count, RUNNER_SLOTS).await;
    let (agent_count, connections) = shape;
    let generated = workflow_with_connections(*agent_count, connections);
    let workflow = create_signed_workflow(test, &account, generated).await;
    let task = workflow_task(project.id, workflow.id);
    save_task(test, &account, task, TaskStart::Now).await;

    let finishing_count = agent_count * FINISHING_ROUNDS_PER_AGENT;
    let finishing_rounds = (0..finishing_count).map(|round| (round, true));
    let mut given_steps = Vec::new();
    let mut unfinished: Vec<(usize, RunAssignment)> = Vec::new();
    for (runner_seed, finishes_first) in
        rounds.into_iter().chain(finishing_rounds)
    {
        if finishes_first && !unfinished.is_empty() {
            let (holder, assignment) = unfinished.remove(0);
            finish_step(test, &runners[holder], &assignment).await;
        }
        let claimer = runner_seed % runners.len();
        let response = claim(test, &runners[claimer]).await;
        if let Some(assignment) = response.assignment {
            given_steps
                .push(describe_given_step(&assignment, &runners[claimer]));
            unfinished.push((claimer, assignment));
        }
    }
    given_steps
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(16))]

    #[test]
    fn test_claim_next_run_property_gives_each_ready_step_to_one_runner(
        shape in workflow_shape(),
        runner_count in 1..=MOST_RUNNERS,
        rounds in proptest::collection::vec(
            (0_usize..8, any::<bool>()),
            0..MOST_ROUNDS,
        ),
    ) {
        let test = TestServer::start();

        let given_steps =
            block_on(give_out_steps(&test, runner_count, &shape, rounds));

        let mut given_names = BTreeSet::new();
        for given_step in &given_steps {
            prop_assert!(given_names.insert(given_step.step_name.clone()));
            prop_assert!(given_step.is_held_by_claimer);
            prop_assert!(given_step.has_upstream_done);
        }
        prop_assert_eq!(given_names.len(), shape.0);
    }
}

#[test]
fn a_recorded_step_result_reaches_the_downstream_assignment() {
    let test = TestServer::start();
    let downstream = block_on(async {
        let account = create_account(&test).await;
        let project = create_project(&test, &account).await;
        let runners = pair_runners(&test, &account, 1, RUNNER_SLOTS).await;
        let generated = workflow_with_connections(2, &[(0, 1)]);
        let workflow =
            create_signed_workflow(&test, &account, generated).await;
        let task = workflow_task(project.id, workflow.id);
        save_task(&test, &account, task, TaskStart::Now).await;
        let first = claim(&test, &runners[0]).await.assignment;
        let first = first.expect("the first step is given");
        let recorded = RunEvent::StepResultRecorded {
            step_name: first.step_name.clone(),
            result: RECORDED_RESULT.to_owned(),
            outcome: None,
        };
        let (status, _run) =
            post_events(&test, &runners[0], &first.run, vec![recorded]).await;
        assert_eq!(status, StatusCode::OK);
        finish_step(&test, &runners[0], &first).await;
        claim(&test, &runners[0]).await.assignment
    });

    let downstream = downstream.expect("the second step is given");
    assert_eq!(downstream.step_name, "step-1");
    let first_step = &downstream.run.steps[0];
    assert_eq!(first_step.result.as_deref(), Some(RECORDED_RESULT));
}

#[test]
fn a_runner_cannot_record_a_result_for_a_step_it_does_not_hold() {
    let test = TestServer::start();
    let status = block_on(async {
        let account = create_account(&test).await;
        let project = create_project(&test, &account).await;
        let runners = pair_runners(&test, &account, 2, RUNNER_SLOTS).await;
        let generated = workflow_with_connections(2, &[(0, 1)]);
        let workflow =
            create_signed_workflow(&test, &account, generated).await;
        let task = workflow_task(project.id, workflow.id);
        save_task(&test, &account, task, TaskStart::Now).await;
        let first = claim(&test, &runners[0]).await.assignment;
        let first = first.expect("the first step is given");
        let recorded = RunEvent::StepResultRecorded {
            step_name: first.step_name.clone(),
            result: RECORDED_RESULT.to_owned(),
            outcome: None,
        };
        let (status, _run) =
            post_events(&test, &runners[1], &first.run, vec![recorded]).await;
        status
    });

    assert_eq!(status, StatusCode::FORBIDDEN);
}
