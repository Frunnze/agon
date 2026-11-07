use orchestration_core::run::{Run, RunStatus, RunStep, StepStatus};
use orchestration_core::run_lifecycle::{
    RunProblem, apply_step_status, derive_run_status, is_run_finished,
    is_step_finished,
};
use proptest::prelude::*;

use crate::entity_strategies::ordinary_timestamp;
use crate::run_fixtures::run_with_steps;
use crate::workflow_strategies::{run_steps, step_status};

fn has_status(steps: &[RunStep], status: StepStatus) -> bool {
    steps.iter().any(|step| step.status == status)
}

proptest! {
    #[test]
    fn test_apply_step_status_property_keeps_run_status_derived(
        steps in run_steps(),
        chosen in any::<prop::sample::Index>(),
        status in step_status(),
        at in ordinary_timestamp(),
    ) {
        let run = run_with_steps(steps);
        prop_assume!(!run.steps.is_empty() && !is_run_finished(run.status));
        let chosen_index = chosen.index(run.steps.len());
        let step_name = run.steps[chosen_index].name.clone();

        let updated = apply_step_status(&run, &step_name, status, at);

        prop_assert!(updated.is_ok());
        if let Ok(updated) = updated {
            let derived_status = derive_run_status(&updated.steps);
            prop_assert_eq!(updated.status, derived_status);
            prop_assert_eq!(
                updated.finished_at.is_some(),
                is_run_finished(updated.status)
            );
            let has_failed = updated.status == RunStatus::Failed;
            for (before, after) in run.steps.iter().zip(&updated.steps) {
                let was_open = !is_step_finished(before.status);
                if before.name == step_name {
                    prop_assert_eq!(after.status, status);
                    prop_assert_eq!(
                        after.finished_at,
                        is_step_finished(status).then_some(at)
                    );
                    if status == StepStatus::Running {
                        prop_assert!(after.started_at.is_some());
                    }
                } else if has_failed && was_open {
                    prop_assert_eq!(after.status, StepStatus::Skipped);
                    prop_assert_eq!(after.finished_at, Some(at));
                } else {
                    prop_assert_eq!(after, before);
                }
            }
        }
    }

    #[test]
    fn test_apply_step_status_property_finished_runs_stay_finished(
        steps in run_steps(),
        status in step_status(),
        at in ordinary_timestamp(),
    ) {
        let finished_run = Run {
            status: RunStatus::Cancelled,
            ..run_with_steps(steps)
        };
        let step_name = finished_run
            .steps
            .first()
            .map(|step| step.name.clone())
            .unwrap_or_default();

        let updated = apply_step_status(&finished_run, &step_name, status, at);

        prop_assert_eq!(updated, Err(RunProblem::RunAlreadyFinished));
    }

    #[test]
    fn test_apply_step_status_fuzz_any_step_name_gives_run_or_problem(
        steps in run_steps(),
        step_name in any::<String>(),
        status in step_status(),
        at in ordinary_timestamp(),
    ) {
        let run = run_with_steps(steps);
        let is_known = run.steps.iter().any(|step| step.name == step_name);

        let updated = apply_step_status(&run, &step_name, status, at);

        match updated {
            Ok(updated) => {
                prop_assert_eq!(updated.steps.len(), run.steps.len());
            }
            Err(RunProblem::UnknownStep { step_name: reported }) => {
                prop_assert!(!is_known);
                prop_assert_eq!(reported, step_name);
            }
            Err(problem) => {
                prop_assert_eq!(problem, RunProblem::RunAlreadyFinished);
                prop_assert!(is_run_finished(run.status));
            }
        }
    }

    #[test]
    fn test_derive_run_status_property_follows_the_most_urgent_step(
        steps in run_steps(),
    ) {
        let status = derive_run_status(&steps);

        let all_finished = steps.iter().all(|step| {
            matches!(step.status, StepStatus::Done | StepStatus::Skipped)
        });
        let all_waiting =
            steps.iter().all(|step| step.status == StepStatus::Waiting);
        let expected = if has_status(&steps, StepStatus::Failed) {
            RunStatus::Failed
        } else if has_status(&steps, StepStatus::WaitingForApproval) {
            RunStatus::WaitingForApproval
        } else if all_waiting {
            RunStatus::Queued
        } else if all_finished {
            RunStatus::Done
        } else {
            RunStatus::Running
        };
        prop_assert_eq!(status, expected);
    }

    #[test]
    fn test_derive_run_status_property_ignores_step_order(
        steps in run_steps(),
    ) {
        let reversed: Vec<RunStep> = steps.iter().rev().cloned().collect();

        let forward_status = derive_run_status(&steps);
        let reversed_status = derive_run_status(&reversed);

        prop_assert_eq!(forward_status, reversed_status);
    }

    #[test]
    fn test_derive_run_status_fuzz_steps_never_cancel_a_run(
        steps in run_steps(),
    ) {
        let status = derive_run_status(&steps);

        prop_assert_ne!(status, RunStatus::Cancelled);
    }
}
