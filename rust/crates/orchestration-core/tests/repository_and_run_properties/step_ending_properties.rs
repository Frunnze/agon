use orchestration_core::run::{RunStatus, RunStep, StepStatus};
use orchestration_core::run_lifecycle::apply_step_status;
use proptest::prelude::*;

use crate::entity_strategies::ordinary_timestamp;
use crate::step_status_support::{
    FINAL_STEP_STATUSES, OPEN_STEP_STATUSES, apply_to_single_step,
    chosen_step_name, recorded_step, unfinished_run,
};
use crate::workflow_strategies::step_status;

proptest! {
    #[test]
    fn test_is_step_finished_property_final_statuses_record_the_end(
        step in recorded_step(),
        status in prop::sample::select(&FINAL_STEP_STATUSES[..]),
        at in ordinary_timestamp(),
    ) {
        let changed = apply_to_single_step(&step, status, at);

        let finished_at = changed.map(|step| step.finished_at);
        prop_assert_eq!(finished_at, Some(Some(at)));
    }

    #[test]
    fn test_is_step_finished_property_open_statuses_clear_the_end(
        step in recorded_step(),
        earlier_end in ordinary_timestamp(),
        status in prop::sample::select(&OPEN_STEP_STATUSES[..]),
        at in ordinary_timestamp(),
    ) {
        let reopened_step = RunStep {
            status: StepStatus::Running,
            finished_at: Some(earlier_end),
            ..step
        };

        let changed = apply_to_single_step(&reopened_step, status, at);

        let finished_at = changed.map(|step| step.finished_at);
        prop_assert_eq!(finished_at, Some(None));
    }

    #[test]
    fn test_is_step_finished_property_finishing_keeps_the_start(
        step in recorded_step(),
        status in prop::sample::select(&FINAL_STEP_STATUSES[..]),
        at in ordinary_timestamp(),
    ) {
        let changed = apply_to_single_step(&step, status, at);

        let started_at = changed.map(|step| step.started_at);
        prop_assert_eq!(started_at, Some(step.started_at));
    }

    #[test]
    fn test_skip_unfinished_steps_property_a_failure_leaves_nothing_open(
        run in unfinished_run(),
        choice in any::<prop::sample::Index>(),
        at in ordinary_timestamp(),
    ) {
        let step_name = chosen_step_name(&run, choice);

        let failed = StepStatus::Failed;
        let changed = apply_step_status(&run, &step_name, failed, at);

        let Ok(changed) = changed else {
            return Err(TestCaseError::fail("a known step must fail"));
        };
        prop_assert_eq!(changed.status, RunStatus::Failed);
        let is_any_open = changed
            .steps
            .iter()
            .any(|step| OPEN_STEP_STATUSES.contains(&step.status));
        prop_assert!(!is_any_open);
    }

    #[test]
    fn test_skip_unfinished_steps_property_a_failure_keeps_finished_steps(
        run in unfinished_run(),
        choice in any::<prop::sample::Index>(),
        at in ordinary_timestamp(),
    ) {
        let step_name = chosen_step_name(&run, choice);

        let failed = StepStatus::Failed;
        let changed = apply_step_status(&run, &step_name, failed, at);

        let Ok(changed) = changed else {
            return Err(TestCaseError::fail("a known step must fail"));
        };
        for (before, after) in run.steps.iter().zip(&changed.steps) {
            let is_bystander = before.name != step_name;
            let was_open = OPEN_STEP_STATUSES.contains(&before.status);
            if is_bystander && !was_open {
                prop_assert_eq!(before, after);
            }
            if is_bystander && was_open {
                prop_assert_eq!(after.status, StepStatus::Skipped);
                prop_assert_eq!(after.finished_at, Some(at));
            }
        }
    }

    #[test]
    fn test_skip_unfinished_steps_property_without_failure_skips_nothing(
        run in unfinished_run(),
        choice in any::<prop::sample::Index>(),
        status in step_status(),
        at in ordinary_timestamp(),
    ) {
        prop_assume!(status != StepStatus::Failed);
        let step_name = chosen_step_name(&run, choice);

        let changed = apply_step_status(&run, &step_name, status, at);

        let Ok(changed) = changed else {
            return Err(TestCaseError::fail("a known step must change"));
        };
        for (before, after) in run.steps.iter().zip(&changed.steps) {
            if before.name != step_name {
                prop_assert_eq!(after.status, before.status);
            }
        }
    }
}
