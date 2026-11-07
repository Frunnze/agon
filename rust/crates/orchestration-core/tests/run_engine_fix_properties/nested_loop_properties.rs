use orchestration_core::run::{RunStatus, StepStatus};
use orchestration_core::workflow_graph::validate_workflow;
use proptest::prelude::*;

use crate::loop_support::count_loop_rounds;
use crate::nested_loop_support::{
    NestedPlan, build_nested_workflow, drive_nested_run, loop_names,
    nested_plan, same_target_plan,
};

fn expected_inner_rounds(plan: NestedPlan) -> u32 {
    plan.inner.round_limit * (plan.outer.round_limit + 1)
}

fn nested_or_same_target_plan() -> impl Strategy<Value = NestedPlan> {
    prop_oneof![nested_plan(), same_target_plan()]
}

proptest! {
    #[test]
    fn test_start_loop_round_property_an_outer_round_restarts_inner_counts(
        plan in nested_or_same_target_plan(),
    ) {
        prop_assert!(validate_workflow(&build_nested_workflow(plan)).is_ok());

        let drive = drive_nested_run(plan);

        prop_assert!(
            drive.unexpected_decisions.is_empty(),
            "{:?}",
            drive.unexpected_decisions
        );
    }

    #[test]
    fn test_count_rounds_property_inner_limit_applies_to_every_outer_pass(
        plan in nested_or_same_target_plan(),
    ) {
        let drive = drive_nested_run(plan);

        prop_assert_eq!(drive.inner_rounds_taken, expected_inner_rounds(plan));
        prop_assert_eq!(drive.outer_rounds_taken, plan.outer.round_limit);
    }

    #[test]
    fn test_count_one_more_round_property_inner_rounds_keep_the_outer_count(
        plan in nested_or_same_target_plan(),
    ) {
        let drive = drive_nested_run(plan);

        let (outer_source, outer_target) = loop_names(plan.outer);
        let (inner_source, inner_target) = loop_names(plan.inner);
        let outer_count =
            count_loop_rounds(&drive.run, &outer_source, &outer_target);
        let inner_count =
            count_loop_rounds(&drive.run, &inner_source, &inner_target);
        prop_assert_eq!(outer_count, plan.outer.round_limit);
        prop_assert_eq!(inner_count, plan.inner.round_limit);
    }

    #[test]
    fn test_start_loop_round_property_nested_loops_still_finish_the_run(
        plan in nested_or_same_target_plan(),
    ) {
        let drive = drive_nested_run(plan);

        prop_assert_eq!(drive.run.status, RunStatus::Done);
        for step in &drive.run.steps {
            prop_assert_eq!(step.status, StepStatus::Done);
        }
    }
}
