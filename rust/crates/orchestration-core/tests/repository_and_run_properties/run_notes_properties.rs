use chrono::{DateTime, Utc};
use orchestration_core::run::{LoopRounds, Run, RunNote, RunStep, StepStatus};
use orchestration_core::run_routing::advance_after_step;
use orchestration_core::workflow::Workflow;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::entity_strategies::ordinary_timestamp;
use crate::routing_fixtures::{connect, fresh_run, routing_workflow};

const LOOP_CONDITION: &str = "again";
const LOOP_SOURCE: &str = "step-2";
const LOOP_TARGET: &str = "step-0";
const SIDE_STEP: &str = "step-3";
const LARGEST_ROUND_LIMIT: u32 = 10;
const MAXIMUM_EARLIER_NOTES: usize = 3;

fn loop_workflow(round_limit: u32, has_side_step: bool) -> Workflow {
    let mut connections = vec![
        connect(0, 1, None, None),
        connect(1, 2, None, None),
        connect(2, 0, Some(LOOP_CONDITION), Some(round_limit)),
    ];
    if has_side_step {
        connections.push(connect(0, 3, None, None));
        return routing_workflow(4, connections);
    }
    routing_workflow(3, connections)
}

fn run_after_rounds(
    workflow: &Workflow,
    rounds: u32,
    earlier_notes: &[RunNote],
) -> Run {
    let fresh = fresh_run(workflow);
    let mut steps = Vec::new();
    for step in &fresh.steps {
        let is_side_step = step.name == SIDE_STEP;
        let status = if is_side_step {
            StepStatus::Running
        } else {
            StepStatus::Done
        };
        let outcome =
            (step.name == LOOP_SOURCE).then(|| LOOP_CONDITION.to_owned());
        steps.push(RunStep {
            status,
            outcome,
            ..step.clone()
        });
    }
    let loop_rounds = vec![LoopRounds {
        from: LOOP_SOURCE.to_owned(),
        to: LOOP_TARGET.to_owned(),
        rounds,
    }];
    Run {
        steps,
        loop_rounds,
        notes: earlier_notes.to_vec(),
        ..fresh
    }
}

fn run_note() -> impl Strategy<Value = RunNote> {
    (ordinary_timestamp(), any::<String>())
        .prop_map(|(at, text)| RunNote { at, text })
}

fn limit_note(round_limit: u32, at: DateTime<Utc>) -> RunNote {
    RunNote {
        at,
        text: format!(
            "{LOOP_SOURCE} → {LOOP_TARGET} reached its limit of \
             {round_limit} rounds"
        ),
    }
}

fn ending_note(at: DateTime<Utc>) -> RunNote {
    RunNote {
        at,
        text: format!(
            "Nothing else follows {LOOP_SOURCE}, so the run finished"
        ),
    }
}

proptest! {
    #[test]
    fn test_add_note_property_reaching_the_limit_appends_its_note(
        round_limit in 1..=LARGEST_ROUND_LIMIT,
        earlier_notes in vec(run_note(), 0..MAXIMUM_EARLIER_NOTES),
        at in ordinary_timestamp(),
    ) {
        let workflow = loop_workflow(round_limit, true);
        let run = run_after_rounds(&workflow, round_limit, &earlier_notes);

        let advanced = advance_after_step(&run, &workflow, LOOP_SOURCE, at);

        let mut expected_notes = earlier_notes.clone();
        expected_notes.push(limit_note(round_limit, at));
        prop_assert_eq!(advanced.notes, expected_notes);
    }

    #[test]
    fn test_add_note_property_a_finished_run_also_notes_its_end(
        round_limit in 1..=LARGEST_ROUND_LIMIT,
        earlier_notes in vec(run_note(), 0..MAXIMUM_EARLIER_NOTES),
        at in ordinary_timestamp(),
    ) {
        let workflow = loop_workflow(round_limit, false);
        let run = run_after_rounds(&workflow, round_limit, &earlier_notes);

        let advanced = advance_after_step(&run, &workflow, LOOP_SOURCE, at);

        let mut expected_notes = earlier_notes.clone();
        expected_notes.push(limit_note(round_limit, at));
        expected_notes.push(ending_note(at));
        prop_assert_eq!(advanced.notes, expected_notes);
        prop_assert_eq!(advanced.finished_at, Some(at));
    }

    #[test]
    fn test_add_note_property_rounds_left_add_no_note(
        (round_limit, rounds) in (1..=LARGEST_ROUND_LIMIT)
            .prop_flat_map(|round_limit| (Just(round_limit), 0..round_limit)),
        has_side_step in any::<bool>(),
        earlier_notes in vec(run_note(), 0..MAXIMUM_EARLIER_NOTES),
        at in ordinary_timestamp(),
    ) {
        let workflow = loop_workflow(round_limit, has_side_step);
        let run = run_after_rounds(&workflow, rounds, &earlier_notes);

        let advanced = advance_after_step(&run, &workflow, LOOP_SOURCE, at);

        prop_assert_eq!(advanced.notes, earlier_notes);
    }
}
