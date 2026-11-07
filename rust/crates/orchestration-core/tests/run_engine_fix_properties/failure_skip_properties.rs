use orchestration_core::run::{RunStatus, RunStep, StepStatus};
use orchestration_core::run_lifecycle::{
    apply_step_status, is_step_finished, skip_unfinished_steps,
};
use proptest::prelude::*;

use crate::entity_strategies::ordinary_timestamp;
use crate::skipped_step_support::{
    choose_step_name, is_step_open, scattered_steps, unfinished_scattered_run,
};

proptest! {
    #[test]
    fn test_apply_step_status_property_a_failed_run_leaves_no_open_step(
        run in unfinished_scattered_run(),
        choice in any::<prop::sample::Index>(),
        at in ordinary_timestamp(),
    ) {
        let step_name = choose_step_name(&run, choice);

        let failed_status = StepStatus::Failed;
        let failed = apply_step_status(&run, &step_name, failed_status, at);

        let Ok(failed) = failed else {
            return Err(TestCaseError::fail("a known step must fail"));
        };
        prop_assert_eq!(failed.status, RunStatus::Failed);
        prop_assert_eq!(failed.finished_at, Some(at));
        for step in &failed.steps {
            prop_assert!(!is_step_open(step.status), "{:?}", step);
        }
    }

    #[test]
    fn test_skip_unfinished_steps_property_a_failure_skips_every_open_step(
        run in unfinished_scattered_run(),
        choice in any::<prop::sample::Index>(),
        at in ordinary_timestamp(),
    ) {
        let step_name = choose_step_name(&run, choice);

        let failed_status = StepStatus::Failed;
        let failed = apply_step_status(&run, &step_name, failed_status, at);

        let Ok(failed) = failed else {
            return Err(TestCaseError::fail("a known step must fail"));
        };
        for (before, after) in run.steps.iter().zip(&failed.steps) {
            let is_bystander = before.name != step_name;
            if is_bystander && is_step_open(before.status) {
                let skipped = RunStep {
                    status: StepStatus::Skipped,
                    finished_at: Some(at),
                    ..before.clone()
                };
                prop_assert_eq!(after, &skipped);
            }
        }
    }

    #[test]
    fn test_skip_unfinished_steps_property_a_failure_keeps_finished_steps(
        run in unfinished_scattered_run(),
        choice in any::<prop::sample::Index>(),
        at in ordinary_timestamp(),
    ) {
        let step_name = choose_step_name(&run, choice);

        let failed_status = StepStatus::Failed;
        let failed = apply_step_status(&run, &step_name, failed_status, at);

        let Ok(failed) = failed else {
            return Err(TestCaseError::fail("a known step must fail"));
        };
        for (before, after) in run.steps.iter().zip(&failed.steps) {
            let is_bystander = before.name != step_name;
            if is_bystander && is_step_finished(before.status) {
                prop_assert_eq!(after, before);
            }
        }
    }

    #[test]
    fn test_skip_unfinished_steps_property_every_skip_records_its_end(
        steps in scattered_steps(),
        at in ordinary_timestamp(),
    ) {
        let settled = skip_unfinished_steps(&steps, at);

        prop_assert_eq!(settled.len(), steps.len());
        for (before, after) in steps.iter().zip(&settled) {
            prop_assert_eq!(&after.name, &before.name);
            prop_assert!(is_step_finished(after.status));
            if is_step_open(before.status) {
                prop_assert_eq!(after.status, StepStatus::Skipped);
                prop_assert_eq!(after.finished_at, Some(at));
            } else {
                prop_assert_eq!(after, before);
            }
        }
    }

    #[test]
    fn test_skip_unfinished_steps_property_is_idempotent(
        steps in scattered_steps(),
        at in ordinary_timestamp(),
        later in ordinary_timestamp(),
    ) {
        let once = skip_unfinished_steps(&steps, at);

        let twice = skip_unfinished_steps(&once, later);

        prop_assert_eq!(twice, once);
    }

    #[test]
    fn test_skip_unfinished_steps_property_keeps_what_each_step_did(
        steps in scattered_steps(),
        at in ordinary_timestamp(),
    ) {
        let settled = skip_unfinished_steps(&steps, at);

        for (before, after) in steps.iter().zip(&settled) {
            prop_assert_eq!(&after.runner, &before.runner);
            prop_assert_eq!(after.started_at, before.started_at);
            prop_assert_eq!(&after.result, &before.result);
            prop_assert_eq!(&after.earlier_rounds, &before.earlier_rounds);
        }
    }

    #[test]
    fn test_is_step_finished_property_exactly_done_failed_and_skipped(
        status in crate::workflow_strategies::step_status(),
    ) {
        let is_final = matches!(
            status,
            StepStatus::Done | StepStatus::Failed | StepStatus::Skipped
        );

        prop_assert_eq!(is_step_finished(status), is_final);
        prop_assert_eq!(is_step_open(status), !is_final);
    }
}
