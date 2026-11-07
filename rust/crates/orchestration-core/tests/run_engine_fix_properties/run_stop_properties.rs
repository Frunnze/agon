use orchestration_core::run::{RunStatus, StepStatus};
use orchestration_core::run_lifecycle::{
    derive_run_status, is_run_finished, is_run_stopped,
};
use proptest::prelude::*;

use crate::skipped_step_support::{ALL_RUN_STATUSES, scattered_steps};

proptest! {
    #[test]
    fn test_is_run_stopped_property_exactly_failed_and_cancelled(
        status in prop::sample::select(&ALL_RUN_STATUSES[..]),
    ) {
        let is_stopped_status =
            matches!(status, RunStatus::Failed | RunStatus::Cancelled);

        prop_assert_eq!(is_run_stopped(status), is_stopped_status);
    }

    #[test]
    fn test_is_run_stopped_property_a_stopped_run_is_finished(
        status in prop::sample::select(&ALL_RUN_STATUSES[..]),
    ) {
        if is_run_stopped(status) {
            prop_assert!(is_run_finished(status));
        }
        let is_done = status == RunStatus::Done;
        prop_assert_eq!(
            is_run_finished(status),
            is_run_stopped(status) || is_done
        );
    }

    #[test]
    fn test_is_run_stopped_property_derived_runs_stop_only_on_a_failure(
        steps in scattered_steps(),
    ) {
        let has_failed_step =
            steps.iter().any(|step| step.status == StepStatus::Failed);

        let derived_status = derive_run_status(&steps);

        prop_assert_eq!(is_run_stopped(derived_status), has_failed_step);
    }
}
