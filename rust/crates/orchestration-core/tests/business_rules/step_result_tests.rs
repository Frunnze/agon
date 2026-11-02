use orchestration_core::run_lifecycle::RunProblem;
use orchestration_core::step_results::record_step_result;
use proptest::prelude::*;

use crate::run_fixtures::{is_run_finished, run_with_steps};
use crate::workflow_strategies::run_steps;

proptest! {
    #[test]
    fn test_record_step_result_property_changes_only_that_steps_result(
        steps in run_steps(),
        chosen in any::<prop::sample::Index>(),
        result in "\\PC{0,80}",
    ) {
        let run = run_with_steps(steps);
        prop_assume!(!run.steps.is_empty() && !is_run_finished(run.status));
        let step_name = run.steps[chosen.index(run.steps.len())].name.clone();

        let recorded = record_step_result(&run, &step_name, &result);

        let Ok(recorded) = recorded else {
            return Err(TestCaseError::fail("the result is recorded"));
        };
        prop_assert_eq!(recorded.status, run.status);
        for (before, after) in run.steps.iter().zip(&recorded.steps) {
            if before.name == step_name {
                let stored_result = after.result.as_deref();
                prop_assert_eq!(stored_result, Some(result.as_str()));
                prop_assert_eq!(after.status, before.status);
                prop_assert_eq!(&after.runner, &before.runner);
            } else {
                prop_assert_eq!(after, before);
            }
        }
    }

    #[test]
    fn test_record_step_result_property_rejects_unknown_steps(
        steps in run_steps(),
        unknown_name in "unknown-[a-z]{1,8}",
        result in "\\PC{0,40}",
    ) {
        let run = run_with_steps(steps);
        prop_assume!(!is_run_finished(run.status));

        let recorded = record_step_result(&run, &unknown_name, &result);

        let expected = RunProblem::UnknownStep {
            step_name: unknown_name,
        };
        prop_assert_eq!(recorded, Err(expected));
    }

    #[test]
    fn test_record_step_result_property_rejects_finished_runs(
        steps in run_steps(),
        chosen in any::<prop::sample::Index>(),
        result in "\\PC{0,40}",
    ) {
        let run = run_with_steps(steps);
        prop_assume!(!run.steps.is_empty() && is_run_finished(run.status));
        let step_name = run.steps[chosen.index(run.steps.len())].name.clone();

        let recorded = record_step_result(&run, &step_name, &result);

        prop_assert_eq!(recorded, Err(RunProblem::RunAlreadyFinished));
    }
}
