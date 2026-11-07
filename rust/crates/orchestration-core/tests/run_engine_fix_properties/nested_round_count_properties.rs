use orchestration_core::run::{LoopRounds, Run};
use orchestration_core::workflow::Workflow;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::loop_support::{
    FORWARD_OUTCOME, LOOP_OUTCOME, count_loop_rounds, step_name,
};
use crate::nested_loop_support::{
    LoopSpan, NestedPlan, build_nested_workflow, loop_names, nested_plan,
    same_target_plan,
};
use crate::routing_fixtures::{finish_step, fresh_run};

const MOST_UNKNOWN_LOOPS: usize = 3;

#[derive(Clone, Copy, Debug)]
struct SeededCounts {
    inner: u32,
    outer: u32,
}

fn seeded_plan() -> impl Strategy<Value = (NestedPlan, SeededCounts)> {
    prop_oneof![nested_plan(), same_target_plan()].prop_flat_map(|plan| {
        let inner = 0..plan.inner.round_limit;
        let outer = 0..plan.outer.round_limit;
        (Just(plan), (inner, outer)).prop_map(|(plan, (inner, outer))| {
            (plan, SeededCounts { inner, outer })
        })
    })
}

fn unknown_loop_rounds() -> impl Strategy<Value = Vec<LoopRounds>> {
    vec(
        ("unknown-[a-z]{1,4}", "[a-z]{1,4}", 0_u32..9),
        0..MOST_UNKNOWN_LOOPS,
    )
    .prop_map(|entries| {
        let mut loop_rounds = Vec::new();
        for (from, to, rounds) in entries {
            loop_rounds.push(LoopRounds { from, to, rounds });
        }
        loop_rounds
    })
}

fn loop_rounds_of(span: LoopSpan, rounds: u32) -> LoopRounds {
    let (from, to) = loop_names(span);
    LoopRounds { from, to, rounds }
}

fn seeded_run(
    plan: NestedPlan,
    counts: SeededCounts,
    unknown: &[LoopRounds],
) -> (Workflow, Run) {
    let workflow = build_nested_workflow(plan);
    let mut loop_rounds = unknown.to_vec();
    loop_rounds.push(loop_rounds_of(plan.inner, counts.inner));
    loop_rounds.push(loop_rounds_of(plan.outer, counts.outer));
    let run = Run {
        loop_rounds,
        ..fresh_run(&workflow)
    };
    (workflow, run)
}

fn take_loop_from(
    plan: NestedPlan,
    workflow: &Workflow,
    run: &Run,
    source: u128,
) -> Run {
    let mut advanced = run.clone();
    for number in 0..source {
        let is_loop_source =
            number == plan.inner.source || number == plan.outer.source;
        let outcome = is_loop_source.then_some(FORWARD_OUTCOME);
        advanced =
            finish_step(&advanced, workflow, &step_name(number), outcome);
    }
    finish_step(&advanced, workflow, &step_name(source), Some(LOOP_OUTCOME))
}

fn count_span(run: &Run, span: LoopSpan) -> u32 {
    let (from, to) = loop_names(span);
    count_loop_rounds(run, &from, &to)
}

proptest! {
    #[test]
    fn test_is_nested_loop_property_an_outer_round_forgets_the_inner_count(
        (plan, counts) in seeded_plan(),
    ) {
        let (workflow, run) = seeded_run(plan, counts, &[]);

        let looped = take_loop_from(plan, &workflow, &run, plan.outer.source);

        prop_assert_eq!(count_span(&looped, plan.inner), 0);
        prop_assert_eq!(count_span(&looped, plan.outer), counts.outer + 1);
    }

    #[test]
    fn test_is_nested_loop_property_an_inner_round_keeps_the_outer_count(
        (plan, counts) in seeded_plan(),
    ) {
        let (workflow, run) = seeded_run(plan, counts, &[]);

        let looped = take_loop_from(plan, &workflow, &run, plan.inner.source);

        prop_assert_eq!(count_span(&looped, plan.outer), counts.outer);
        prop_assert_eq!(count_span(&looped, plan.inner), counts.inner + 1);
    }

    #[test]
    fn test_is_nested_loop_property_the_taken_loop_keeps_counting(
        (plan, counts) in seeded_plan(),
    ) {
        let (workflow, run) = seeded_run(plan, counts, &[]);

        let looped = take_loop_from(plan, &workflow, &run, plan.outer.source);
        let outer_source = plan.outer.source;
        let again = take_loop_from(plan, &workflow, &looped, outer_source);

        let expected = (counts.outer + 2).min(plan.outer.round_limit);
        prop_assert_eq!(count_span(&again, plan.outer), expected);
    }

    #[test]
    fn test_forget_nested_loop_rounds_property_keeps_unknown_loops_in_order(
        (plan, counts) in seeded_plan(),
        unknown in unknown_loop_rounds(),
        is_outer_taken in any::<bool>(),
    ) {
        let (workflow, run) = seeded_run(plan, counts, &unknown);
        let span = if is_outer_taken { plan.outer } else { plan.inner };

        let looped = take_loop_from(plan, &workflow, &run, span.source);

        let kept: Vec<LoopRounds> = looped
            .loop_rounds
            .iter()
            .filter(|rounds| rounds.from.starts_with("unknown-"))
            .cloned()
            .collect();
        prop_assert_eq!(kept, unknown);
    }

    #[test]
    fn test_forget_nested_loop_rounds_property_leaves_one_entry_per_loop(
        (plan, counts) in seeded_plan(),
        is_outer_taken in any::<bool>(),
    ) {
        let (workflow, run) = seeded_run(plan, counts, &[]);
        let span = if is_outer_taken { plan.outer } else { plan.inner };

        let looped = take_loop_from(plan, &workflow, &run, span.source);

        for checked_span in [plan.inner, plan.outer] {
            let (from, to) = loop_names(checked_span);
            let entries = looped
                .loop_rounds
                .iter()
                .filter(|rounds| rounds.from == from && rounds.to == to)
                .count();
            prop_assert!(entries <= 1);
        }
    }

    #[test]
    fn test_forget_nested_loop_rounds_property_drops_the_inner_entry(
        (plan, counts) in seeded_plan(),
    ) {
        let (workflow, run) = seeded_run(plan, counts, &[]);

        let looped = take_loop_from(plan, &workflow, &run, plan.outer.source);

        let (from, to) = loop_names(plan.inner);
        let has_inner_entry = looped
            .loop_rounds
            .iter()
            .any(|rounds| rounds.from == from && rounds.to == to);
        prop_assert!(!has_inner_entry);
    }
}
