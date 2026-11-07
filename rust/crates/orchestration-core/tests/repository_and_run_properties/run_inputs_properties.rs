use chrono::DateTime;
use orchestration_core::run::{Run, RunStatus, RunStep, StepStatus};
use orchestration_core::run_routing::{
    is_step_claimable, settle_waiting_steps,
};
use orchestration_core::workflow::Workflow;
use proptest::option;
use proptest::prelude::*;

use crate::routing_fixtures::{
    connect, finish_step, fresh_run, routing_workflow, step_named,
};
use crate::run_fixtures::run_with_steps;

const PENDING_STATUSES: [StepStatus; 4] = [
    StepStatus::Waiting,
    StepStatus::Running,
    StepStatus::WaitingForApproval,
    StepStatus::WaitingForPerson,
];
const JOIN_OUTCOMES: [Option<&str>; 3] = [None, Some("left"), Some("right")];
const LONGEST_CHAIN: u128 = 6;
const TAKEN_CONDITION: &str = "go";
const FIRST_STEP: &str = "step-0";
const SECOND_STEP: &str = "step-1";
const THIRD_STEP: &str = "step-2";

fn with_step_status(run: &Run, step_name: &str, status: StepStatus) -> Run {
    let mut steps = Vec::new();
    for step in &run.steps {
        if step.name == step_name {
            steps.push(RunStep {
                status,
                ..step.clone()
            });
        } else {
            steps.push(step.clone());
        }
    }
    run_with_steps(steps)
}

fn chain_workflow(step_count: u128, first_condition: &str) -> Workflow {
    let mut connections = vec![connect(0, 1, Some(first_condition), None)];
    for from in 1..step_count - 1 {
        connections.push(connect(from, from + 1, None, None));
    }
    routing_workflow(step_count, connections)
}

fn is_claimable_in(run: &Run, workflow: &Workflow, step_name: &str) -> bool {
    is_step_claimable(run, step_named(run, step_name), Some(workflow))
}

fn outcome_variant() -> impl Strategy<Value = Option<String>> {
    prop_oneof![
        Just(Some(TAKEN_CONDITION.to_owned())),
        Just(Some(TAKEN_CONDITION.to_uppercase())),
        Just(Some(format!(" {TAKEN_CONDITION}"))),
        Just(None),
        any::<String>().prop_map(Some),
    ]
}

proptest! {
    #[test]
    fn test_read_input_state_property_a_pending_input_holds_the_step(
        status in prop::sample::select(&PENDING_STATUSES[..]),
        is_joined in any::<bool>(),
    ) {
        let workflow = if is_joined {
            routing_workflow(3, vec![
                connect(0, 2, None, None),
                connect(1, 2, None, None),
            ])
        } else {
            routing_workflow(3, vec![connect(1, 2, None, None)])
        };
        let fresh = fresh_run(&workflow);
        let source_done = finish_step(&fresh, &workflow, FIRST_STEP, None);
        let pending_run = with_step_status(&source_done, SECOND_STEP, status);

        let at = DateTime::UNIX_EPOCH;
        let settled = settle_waiting_steps(&pending_run, &workflow, at);

        let join = step_named(&settled, THIRD_STEP);
        prop_assert_eq!(join.status, StepStatus::Waiting);
        prop_assert!(!is_claimable_in(&settled, &workflow, THIRD_STEP));
    }

    #[test]
    fn test_read_input_state_property_skipping_runs_down_the_chain(
        step_count in 2..=LONGEST_CHAIN,
        outcome in outcome_variant(),
    ) {
        prop_assume!(outcome.as_deref() != Some(TAKEN_CONDITION));
        let workflow = chain_workflow(step_count, TAKEN_CONDITION);

        let finished = finish_step(
            &fresh_run(&workflow),
            &workflow,
            FIRST_STEP,
            outcome.as_deref(),
        );

        for step in finished.steps.iter().skip(1) {
            prop_assert_eq!(step.status, StepStatus::Skipped);
            prop_assert_eq!(step.finished_at, Some(DateTime::UNIX_EPOCH));
        }
        prop_assert_eq!(finished.status, RunStatus::Done);
        prop_assert_eq!(finished.finished_at, Some(DateTime::UNIX_EPOCH));
    }

    #[test]
    fn test_is_connection_taken_property_plain_connections_always_lead_on(
        outcome in option::of(any::<String>()),
    ) {
        let workflow = routing_workflow(2, vec![connect(0, 1, None, None)]);

        let finished = finish_step(
            &fresh_run(&workflow),
            &workflow,
            FIRST_STEP,
            outcome.as_deref(),
        );

        prop_assert!(is_claimable_in(&finished, &workflow, SECOND_STEP));
    }

    #[test]
    fn test_is_connection_taken_property_conditions_match_exactly(
        outcome in outcome_variant(),
    ) {
        let workflow = chain_workflow(2, TAKEN_CONDITION);

        let finished = finish_step(
            &fresh_run(&workflow),
            &workflow,
            FIRST_STEP,
            outcome.as_deref(),
        );

        let is_taken = outcome.as_deref() == Some(TAKEN_CONDITION);
        let target = step_named(&finished, SECOND_STEP);
        let expected_status = if is_taken {
            StepStatus::Waiting
        } else {
            StepStatus::Skipped
        };
        prop_assert_eq!(target.status, expected_status);
        let is_claimable = is_claimable_in(&finished, &workflow, SECOND_STEP);
        prop_assert_eq!(is_claimable, is_taken);
    }

    #[test]
    fn test_is_connection_taken_property_a_join_needs_one_taken_input(
        left_outcome in prop::sample::select(&JOIN_OUTCOMES[..]),
        right_outcome in prop::sample::select(&JOIN_OUTCOMES[..]),
    ) {
        let workflow = routing_workflow(3, vec![
            connect(0, 2, Some("left"), None),
            connect(1, 2, Some("right"), None),
        ]);
        let run = fresh_run(&workflow);

        let left_done = finish_step(&run, &workflow, FIRST_STEP, left_outcome);
        let both_done =
            finish_step(&left_done, &workflow, SECOND_STEP, right_outcome);

        let is_taken =
            left_outcome == Some("left") || right_outcome == Some("right");
        let join = step_named(&both_done, THIRD_STEP);
        let expected_status = if is_taken {
            StepStatus::Waiting
        } else {
            StepStatus::Skipped
        };
        prop_assert_eq!(join.status, expected_status);
        let is_claimable = is_claimable_in(&both_done, &workflow, THIRD_STEP);
        prop_assert_eq!(is_claimable, is_taken);
    }
}
