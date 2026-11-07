use chrono::{DateTime, Utc};
use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::run::{Run, RunStatus, RunStep, StepStatus};
use orchestration_core::run_lifecycle::{derive_run_status, is_run_finished};
use orchestration_core::run_routing::{
    is_step_claimable, settle_waiting_steps,
};
use orchestration_core::workflow::{StepKind, Workflow, WorkflowAgent};
use orchestration_core::workflow_graph::find_agent_by_id;
use proptest::prelude::*;

use crate::entity_strategies::ordinary_timestamp;
use crate::routing_run_strategies::{RoutedRun, fresh_routed_run, routed_run};
use crate::workflow_strategies::{agent_identifier, workflow_from_parts};

const FINAL_RUN_STATUSES: [RunStatus; 3] =
    [RunStatus::Done, RunStatus::Failed, RunStatus::Cancelled];
const UNKNOWN_AGENT_NUMBER: u128 = 1_000;

fn as_agent_steps(workflow: &Workflow) -> Workflow {
    let mut agents = Vec::new();
    for agent in &workflow.agents {
        agents.push(WorkflowAgent {
            step_kind: StepKind::Agent,
            ..agent.clone()
        });
    }
    workflow_from_parts(agents, workflow.connections.clone())
}

fn is_person_step(workflow: &Workflow, step: &RunStep) -> bool {
    let agent = step
        .agent_id
        .and_then(|agent_id| find_agent_by_id(workflow, agent_id));
    agent.is_some_and(|agent| agent.step_kind == StepKind::Person)
}

fn outside_step(name: &str, agent_id: Option<WorkflowAgentId>) -> RunStep {
    RunStep {
        name: name.to_owned(),
        agent_id,
        runner: None,
        status: StepStatus::Waiting,
        started_at: None,
        finished_at: None,
        result: None,
        outcome: None,
        loop_source: None,
        earlier_rounds: Vec::new(),
    }
}

fn with_outside_steps(run: &Run) -> Run {
    let unknown_agent = Some(agent_identifier(UNKNOWN_AGENT_NUMBER));
    let mut steps = run.steps.clone();
    steps.push(outside_step("outside-none", None));
    steps.push(outside_step("outside-unknown", unknown_agent));
    Run {
        steps,
        ..run.clone()
    }
}

fn settle_at(routed: &RoutedRun, at: DateTime<Utc>) -> Run {
    settle_waiting_steps(&routed.run, &routed.workflow, at)
}

proptest! {
    #[test]
    fn test_settle_waiting_steps_property_is_idempotent(
        routed in routed_run(),
        at in ordinary_timestamp(),
    ) {
        let settled_once = settle_at(&routed, at);

        let settled_twice =
            settle_waiting_steps(&settled_once, &routed.workflow, at);

        prop_assert_eq!(settled_twice, settled_once);
    }

    #[test]
    fn test_settle_waiting_steps_property_leaves_finished_runs_alone(
        routed in routed_run(),
        status in prop::sample::select(&FINAL_RUN_STATUSES[..]),
        at in ordinary_timestamp(),
    ) {
        let finished_run = Run { status, ..routed.run };

        let workflow = &routed.workflow;
        let settled = settle_waiting_steps(&finished_run, workflow, at);

        prop_assert_eq!(settled, finished_run);
    }

    #[test]
    fn test_settle_waiting_steps_property_touches_only_open_steps(
        routed in routed_run(),
        at in ordinary_timestamp(),
    ) {
        let settled = settle_at(&routed, at);

        prop_assert_eq!(settled.status, derive_run_status(&settled.steps));
        for (before, after) in routed.run.steps.iter().zip(&settled.steps) {
            let is_waiting = before.status == StepStatus::Waiting;
            let is_open = is_waiting && before.runner.is_none();
            if !is_open {
                prop_assert_eq!(before, after);
            }
        }
    }

    #[test]
    fn test_find_settling_step_property_settled_steps_record_the_moment(
        routed in routed_run(),
        at in ordinary_timestamp(),
    ) {
        let settled = settle_at(&routed, at);

        for (before, after) in routed.run.steps.iter().zip(&settled.steps) {
            if before == after {
                continue;
            }
            let is_person = is_person_step(&routed.workflow, after);
            match after.status {
                StepStatus::Skipped => {
                    prop_assert_eq!(after.finished_at, Some(at));
                }
                StepStatus::WaitingForPerson => {
                    prop_assert!(is_person);
                    prop_assert_eq!(after.started_at, Some(at));
                }
                other => {
                    return Err(TestCaseError::fail(format!("{other:?}")));
                }
            }
        }
    }

    #[test]
    fn test_find_settling_step_property_steps_outside_the_workflow_stay(
        routed in routed_run(),
        at in ordinary_timestamp(),
    ) {
        let widened_run = with_outside_steps(&routed.run);

        let settled = settle_waiting_steps(&widened_run, &routed.workflow, at);

        let outside_count = 2;
        let first_outside = settled.steps.len().saturating_sub(outside_count);
        let widened_outside = &widened_run.steps[first_outside..];
        prop_assert_eq!(&settled.steps[first_outside..], widened_outside);
    }

    #[test]
    fn test_find_settling_step_property_no_ready_person_step_is_left(
        routed in routed_run().prop_filter("unfinished", |routed| {
            !is_run_finished(routed.run.status)
        }),
        at in ordinary_timestamp(),
    ) {
        let settled = settle_at(&routed, at);

        let agent_workflow = as_agent_steps(&routed.workflow);
        for step in &settled.steps {
            if !is_person_step(&routed.workflow, step) {
                continue;
            }
            let workflow = Some(&agent_workflow);
            let is_ready = is_step_claimable(&settled, step, workflow);
            prop_assert!(!is_ready, "{} was left waiting", step.name);
        }
    }

    #[test]
    fn test_read_input_state_property_steps_without_inputs_are_ready(
        routed in fresh_routed_run(),
        at in ordinary_timestamp(),
    ) {
        let settled = settle_at(&routed, at);

        for step in &settled.steps {
            let connections = &routed.workflow.connections;
            let has_input = connections.iter().any(|connection| {
                !connection.is_loop() && Some(connection.to) == step.agent_id
            });
            if has_input {
                continue;
            }
            let expected_status = if is_person_step(&routed.workflow, step) {
                StepStatus::WaitingForPerson
            } else {
                StepStatus::Waiting
            };
            prop_assert_eq!(step.status, expected_status);
            let workflow = Some(&routed.workflow);
            let is_claimable = is_step_claimable(&settled, step, workflow);
            let should_be_claimable = expected_status == StepStatus::Waiting;
            prop_assert_eq!(is_claimable, should_be_claimable);
        }
    }
}
