use orchestration_core::run::{Run, RunStatus, RunStep, StepStatus};
use orchestration_core::run_lifecycle::{
    RunProblem, apply_step_status, is_run_finished,
};
use proptest::prelude::*;

use crate::entity_strategies::ordinary_timestamp;
use crate::step_status_support::{
    OPEN_STEP_STATUSES, apply_to_single_step, chosen_step_name, recorded_step,
    unfinished_run,
};
use crate::workflow_strategies::step_status;

fn find_step<'run>(run: &'run Run, step_name: &str) -> Option<&'run RunStep> {
    run.steps.iter().find(|step| step.name == step_name)
}

proptest! {
    #[test]
    fn test_apply_step_status_property_other_steps_stay_unless_failing(
        run in unfinished_run(),
        choice in any::<prop::sample::Index>(),
        status in step_status(),
        at in ordinary_timestamp(),
    ) {
        let step_name = chosen_step_name(&run, choice);

        let changed = apply_step_status(&run, &step_name, status, at);

        let Ok(changed) = changed else {
            return Err(TestCaseError::fail("a known step must change"));
        };
        prop_assume!(changed.status != RunStatus::Failed);
        for (before, after) in run.steps.iter().zip(&changed.steps) {
            if before.name != step_name {
                prop_assert_eq!(before, after);
            }
        }
    }

    #[test]
    fn test_apply_step_status_property_refuses_unknown_step_names(
        run in unfinished_run(),
        step_name in any::<String>(),
        status in step_status(),
        at in ordinary_timestamp(),
    ) {
        prop_assume!(find_step(&run, &step_name).is_none());

        let changed = apply_step_status(&run, &step_name, status, at);

        prop_assert_eq!(changed, Err(RunProblem::UnknownStep { step_name }));
    }

    #[test]
    fn test_apply_step_status_property_run_end_matches_its_status(
        run in unfinished_run(),
        choice in any::<prop::sample::Index>(),
        status in step_status(),
        at in ordinary_timestamp(),
    ) {
        let step_name = chosen_step_name(&run, choice);

        let changed = apply_step_status(&run, &step_name, status, at);

        let Ok(changed) = changed else {
            return Err(TestCaseError::fail("a known step must change"));
        };
        let expected_end = is_run_finished(changed.status).then_some(at);
        prop_assert_eq!(changed.finished_at, expected_end);
    }

    #[test]
    fn test_change_step_status_property_first_start_is_kept(
        step in recorded_step(),
        first_at in ordinary_timestamp(),
        later_at in ordinary_timestamp(),
        pause in prop::sample::select(&OPEN_STEP_STATUSES[..]),
    ) {
        let unstarted_step = RunStep { started_at: None, ..step };

        let started = apply_to_single_step(
            &unstarted_step,
            StepStatus::Running,
            first_at,
        );
        let paused = started.and_then(|step| {
            apply_to_single_step(&step, pause, later_at)
        });
        let resumed = paused.and_then(|step| {
            apply_to_single_step(&step, StepStatus::Running, later_at)
        });

        let started_at = resumed.and_then(|step| step.started_at);
        prop_assert_eq!(started_at, Some(first_at));
    }

    #[test]
    fn test_change_step_status_property_keeps_what_the_step_recorded(
        step in recorded_step(),
        status in step_status(),
        at in ordinary_timestamp(),
    ) {
        let changed = apply_to_single_step(&step, status, at);

        let Some(changed) = changed else {
            return Err(TestCaseError::fail("a known step must change"));
        };
        prop_assert_eq!(&changed.name, &step.name);
        prop_assert_eq!(&changed.runner, &step.runner);
        prop_assert_eq!(&changed.result, &step.result);
        prop_assert_eq!(&changed.outcome, &step.outcome);
        prop_assert_eq!(&changed.loop_source, &step.loop_source);
        prop_assert_eq!(&changed.earlier_rounds, &step.earlier_rounds);
        prop_assert_eq!(changed.status, status);
    }

    #[test]
    fn test_change_step_status_property_only_running_starts_a_step(
        step in recorded_step(),
        status in step_status(),
        at in ordinary_timestamp(),
    ) {
        prop_assume!(status != StepStatus::Running);
        let unstarted_step = RunStep { started_at: None, ..step };

        let changed = apply_to_single_step(&unstarted_step, status, at);

        let started_at = changed.map(|step| step.started_at);
        prop_assert_eq!(started_at, Some(None));
    }
}
