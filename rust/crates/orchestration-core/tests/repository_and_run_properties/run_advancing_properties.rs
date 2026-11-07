use chrono::{DateTime, Utc};
use orchestration_core::run::{Run, RunStep, StepStatus};
use orchestration_core::run_lifecycle::RunProblem;
use orchestration_core::run_routing::{
    advance_after_step, advance_newly_done_steps, settle_waiting_steps,
};
use orchestration_core::step_outcomes::list_step_choices;
use orchestration_core::workflow::Workflow;
use proptest::collection::vec;
use proptest::option;
use proptest::prelude::*;

use crate::entity_strategies::ordinary_timestamp;
use crate::routing_run_strategies::{RoutedRun, fresh_routed_run, routed_run};
use crate::run_fixtures::run_with_steps;

const MAXIMUM_FINISHED_STEPS: usize = 4;
const UNKNOWN_OUTCOME: &str = "not one of the choices";

fn choices_of(workflow: &Workflow, step: &RunStep) -> Vec<String> {
    step.agent_id
        .map(|agent_id| list_step_choices(workflow, agent_id))
        .unwrap_or_default()
}

fn known_outcome(
    workflow: &Workflow,
    step: &RunStep,
    pick: prop::sample::Index,
) -> Option<String> {
    let choices = choices_of(workflow, step);
    if choices.is_empty() {
        return None;
    }
    Some(choices[pick.index(choices.len())].clone())
}

fn finish_in(run: &Run, index: usize, outcome: Option<String>) -> Run {
    let mut steps = run.steps.clone();
    steps[index] = RunStep {
        status: StepStatus::Done,
        outcome,
        ..steps[index].clone()
    };
    run_with_steps(steps)
}

fn advance_routed(
    routed: &RoutedRun,
    after: &Run,
    at: DateTime<Utc>,
) -> Result<Run, RunProblem> {
    advance_newly_done_steps(&routed.run, after, &routed.workflow, at)
}

fn routed_run_with_steps(
    has_choices: bool,
) -> impl Strategy<Value = RoutedRun> {
    fresh_routed_run().prop_filter("a fitting step", move |routed| {
        !positions_where(routed, has_choices).is_empty()
    })
}

fn positions_where(routed: &RoutedRun, has_choices: bool) -> Vec<usize> {
    let mut positions = Vec::new();
    for (position, step) in routed.run.steps.iter().enumerate() {
        let step_has_choices = !choices_of(&routed.workflow, step).is_empty();
        if step_has_choices == has_choices {
            positions.push(position);
        }
    }
    positions
}

proptest! {
    #[test]
    fn test_advance_newly_done_steps_property_nothing_new_changes_nothing(
        routed in routed_run(),
        at in ordinary_timestamp(),
    ) {
        let advanced = advance_routed(&routed, &routed.run, at);

        prop_assert_eq!(advanced, Ok(routed.run.clone()));
    }

    #[test]
    fn test_advance_newly_done_steps_property_one_new_step_is_advanced(
        routed in routed_run(),
        choice in any::<prop::sample::Index>(),
        pick in any::<prop::sample::Index>(),
        at in ordinary_timestamp(),
    ) {
        let index = choice.index(routed.run.steps.len());
        let step = &routed.run.steps[index];
        prop_assume!(step.status != StepStatus::Done);
        let outcome = known_outcome(&routed.workflow, step, pick);
        let after = finish_in(&routed.run, index, outcome);

        let advanced = advance_routed(&routed, &after, at);

        let expected =
            advance_after_step(&after, &routed.workflow, &step.name, at);
        prop_assert_eq!(advanced, Ok(expected));
    }

    #[test]
    fn test_advance_newly_done_steps_property_result_is_settled(
        routed in routed_run(),
        finished in vec(
            (any::<prop::sample::Index>(), any::<prop::sample::Index>()),
            1..MAXIMUM_FINISHED_STEPS,
        ),
        at in ordinary_timestamp(),
    ) {
        let mut after = routed.run.clone();
        let mut has_newly_done = false;
        for (choice, pick) in &finished {
            let index = choice.index(after.steps.len());
            let step = &after.steps[index];
            let was_done = routed.run.steps[index].status == StepStatus::Done;
            has_newly_done = has_newly_done || !was_done;
            let outcome = known_outcome(&routed.workflow, step, *pick);
            after = finish_in(&after, index, outcome);
        }
        prop_assume!(has_newly_done);

        let advanced = advance_routed(&routed, &after, at);

        let Ok(advanced) = advanced else {
            return Err(TestCaseError::fail("known outcomes must advance"));
        };
        let settled = settle_waiting_steps(&advanced, &routed.workflow, at);
        prop_assert_eq!(settled, advanced);
    }

    #[test]
    fn test_require_known_outcome_property_names_the_step_and_choices(
        routed in routed_run_with_steps(true),
        choice in any::<prop::sample::Index>(),
        outcome in prop_oneof![
            Just(None),
            Just(Some(UNKNOWN_OUTCOME.to_owned())),
        ],
        at in ordinary_timestamp(),
    ) {
        let positions = positions_where(&routed, true);
        let index = positions[choice.index(positions.len())];
        let step = &routed.run.steps[index];
        let after = finish_in(&routed.run, index, outcome);

        let advanced = advance_routed(&routed, &after, at);

        let expected = RunProblem::UnknownOutcome {
            step_name: step.name.clone(),
            choices: choices_of(&routed.workflow, step),
        };
        prop_assert_eq!(advanced, Err(expected));
    }

    #[test]
    fn test_require_known_outcome_property_known_outcomes_pass(
        routed in routed_run_with_steps(true),
        choice in any::<prop::sample::Index>(),
        pick in any::<prop::sample::Index>(),
        at in ordinary_timestamp(),
    ) {
        let positions = positions_where(&routed, true);
        let index = positions[choice.index(positions.len())];
        let step = &routed.run.steps[index];
        let outcome = known_outcome(&routed.workflow, step, pick);
        let after = finish_in(&routed.run, index, outcome);

        let advanced = advance_routed(&routed, &after, at);

        prop_assert!(advanced.is_ok(), "{:?}", advanced);
    }

    #[test]
    fn test_require_known_outcome_property_steps_without_choices_pass(
        routed in routed_run_with_steps(false),
        choice in any::<prop::sample::Index>(),
        outcome in option::of(any::<String>()),
        is_outside in any::<bool>(),
        at in ordinary_timestamp(),
    ) {
        let positions = positions_where(&routed, false);
        let index = positions[choice.index(positions.len())];
        let mut after = finish_in(&routed.run, index, outcome);
        if is_outside {
            after.steps[index].agent_id = None;
        }

        let advanced = advance_routed(&routed, &after, at);

        prop_assert!(advanced.is_ok(), "{:?}", advanced);
    }
}
