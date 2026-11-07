use chrono::DateTime;
use orchestration_core::run::{LoopRounds, Run, StepStatus};
use orchestration_core::run_routing::advance_after_step;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::loop_support::{
    FORWARD_OUTCOME, LOOP_OUTCOME, LoopPlan, build_loop_workflow,
    count_loop_rounds, finish_round, loop_plan, step_name,
};
use crate::routing_fixtures::{finish_step, fresh_run};
use crate::workflow_strategies::step_status;

const MAXIMUM_OTHER_LOOPS: usize = 3;

fn other_loop_rounds() -> impl Strategy<Value = Vec<LoopRounds>> {
    vec(
        ("other-[a-z]{1,3}", "[a-z-]{1,6}", 0_u32..20),
        0..MAXIMUM_OTHER_LOOPS,
    )
    .prop_map(|entries| {
        let mut loop_rounds = Vec::new();
        for (from, to, rounds) in entries {
            loop_rounds.push(LoopRounds { from, to, rounds });
        }
        loop_rounds
    })
}

fn loop_names(plan: LoopPlan) -> (String, String) {
    (step_name(plan.source), step_name(plan.target))
}

fn with_loop_rounds(run: &Run, loop_rounds: Vec<LoopRounds>) -> Run {
    Run {
        loop_rounds,
        ..run.clone()
    }
}

fn count_loops_taken(plan: LoopPlan, first_run: &Run) -> u32 {
    let workflow = build_loop_workflow(plan);
    let (source, target) = loop_names(plan);
    let mut run = finish_round(first_run, &workflow, plan, 0);
    let first_rounds = count_loop_rounds(first_run, &source, &target);
    let mut taken = count_loop_rounds(&run, &source, &target) - first_rounds;
    for _ in 0..=plan.round_limit {
        let next = finish_round(&run, &workflow, plan, plan.target);
        let rounds_before = count_loop_rounds(&run, &source, &target);
        if count_loop_rounds(&next, &source, &target) == rounds_before {
            break;
        }
        taken += 1;
        run = next;
    }
    taken
}

proptest! {
    #[test]
    fn test_find_taken_loop_property_takes_the_loop_the_outcome_names(
        plan in loop_plan(),
    ) {
        let workflow = build_loop_workflow(plan);
        let (source, target) = loop_names(plan);

        let run = finish_round(&fresh_run(&workflow), &workflow, plan, 0);

        prop_assert_eq!(run.loop_rounds, vec![LoopRounds {
            from: source.clone(),
            to: target.clone(),
            rounds: 1,
        }]);
        let target_step = run.steps.iter().find(|step| step.name == target);
        let waits_with_the_source = target_step.is_some_and(|step| {
            step.status == StepStatus::Waiting
                && step.loop_source.as_deref() == Some(source.as_str())
        });
        prop_assert!(waits_with_the_source);
    }

    #[test]
    fn test_find_taken_loop_property_ignores_every_other_outcome(
        plan in loop_plan(),
        outcome in prop_oneof![
            Just(None),
            Just(Some(FORWARD_OUTCOME.to_owned())),
            "[a-z ]{0,8}".prop_map(Some),
        ],
    ) {
        if outcome.as_deref() == Some(LOOP_OUTCOME) {
            return Ok(());
        }
        let workflow = build_loop_workflow(plan);
        let mut run = fresh_run(&workflow);
        for number in 0..plan.source {
            run = finish_step(&run, &workflow, &step_name(number), None);
        }

        let source = step_name(plan.source);
        let finished =
            finish_step(&run, &workflow, &source, outcome.as_deref());

        prop_assert!(finished.loop_rounds.is_empty());
        for step in &finished.steps {
            prop_assert!(step.earlier_rounds.is_empty());
        }
    }

    #[test]
    fn test_find_taken_loop_property_needs_the_step_to_be_done(
        plan in loop_plan(),
        status in step_status().prop_filter(
            "a done step may take the loop",
            |status| *status != StepStatus::Done,
        ),
    ) {
        let workflow = build_loop_workflow(plan);
        let mut run = fresh_run(&workflow);
        let source = step_name(plan.source);
        for step in &mut run.steps {
            if step.name == source {
                step.status = status;
                step.outcome = Some(LOOP_OUTCOME.to_owned());
            }
        }

        let advanced =
            advance_after_step(&run, &workflow, &source, DateTime::UNIX_EPOCH);

        prop_assert!(advanced.loop_rounds.is_empty());
    }

    #[test]
    fn test_count_rounds_property_loops_exactly_the_round_limit(
        plan in loop_plan(),
    ) {
        let workflow = build_loop_workflow(plan);

        let taken = count_loops_taken(plan, &fresh_run(&workflow));

        prop_assert_eq!(taken, plan.round_limit);
    }

    #[test]
    fn test_count_rounds_property_other_loops_do_not_count(
        plan in loop_plan(),
        others in other_loop_rounds(),
    ) {
        let workflow = build_loop_workflow(plan);
        let seeded = with_loop_rounds(&fresh_run(&workflow), others);

        let taken = count_loops_taken(plan, &seeded);

        prop_assert_eq!(taken, plan.round_limit);
    }

    #[test]
    fn test_count_rounds_property_continues_from_rounds_already_taken(
        plan in loop_plan(),
        already_taken in 0_u32..12,
    ) {
        let workflow = build_loop_workflow(plan);
        let (source, target) = loop_names(plan);
        let seeded = with_loop_rounds(&fresh_run(&workflow), vec![LoopRounds {
            from: source,
            to: target,
            rounds: already_taken,
        }]);

        let taken = count_loops_taken(plan, &seeded);

        prop_assert_eq!(taken, plan.round_limit.saturating_sub(already_taken));
    }

    #[test]
    fn test_count_one_more_round_property_adds_one_to_that_loop_only(
        plan in loop_plan(),
        others in other_loop_rounds(),
        position in any::<prop::sample::Index>(),
    ) {
        let workflow = build_loop_workflow(plan);
        let (source, target) = loop_names(plan);
        let mut seeded_rounds = others.clone();
        let this_loop = LoopRounds {
            from: source.clone(),
            to: target.clone(),
            rounds: 0,
        };
        seeded_rounds.insert(position.index(others.len() + 1), this_loop);
        let seeded = with_loop_rounds(&fresh_run(&workflow), seeded_rounds);

        let run = finish_round(&seeded, &workflow, plan, 0);

        let mut expected = Vec::new();
        for loop_rounds in &seeded.loop_rounds {
            let is_this_loop = loop_rounds.from == source
                && loop_rounds.to == target;
            let rounds = loop_rounds.rounds + u32::from(is_this_loop);
            expected.push(LoopRounds { rounds, ..loop_rounds.clone() });
        }
        prop_assert_eq!(run.loop_rounds, expected);
    }

    #[test]
    fn test_count_one_more_round_property_starts_a_new_loop_last(
        plan in loop_plan(),
        others in other_loop_rounds(),
    ) {
        let workflow = build_loop_workflow(plan);
        let (source, target) = loop_names(plan);
        let seeded = with_loop_rounds(&fresh_run(&workflow), others.clone());

        let run = finish_round(&seeded, &workflow, plan, 0);

        let mut expected = others;
        expected.push(LoopRounds { from: source, to: target, rounds: 1 });
        prop_assert_eq!(run.loop_rounds, expected);
    }

    #[test]
    fn test_count_one_more_round_property_keeps_one_entry_per_loop(
        plan in loop_plan(),
        rounds_to_take in 1_u32..4,
    ) {
        let workflow = build_loop_workflow(plan);
        let (source, target) = loop_names(plan);
        let mut run = finish_round(&fresh_run(&workflow), &workflow, plan, 0);
        for _ in 1..rounds_to_take {
            run = finish_round(&run, &workflow, plan, plan.target);
        }

        let entries = run
            .loop_rounds
            .iter()
            .filter(|rounds| rounds.from == source && rounds.to == target)
            .count();

        prop_assert_eq!(entries, 1);
    }
}
