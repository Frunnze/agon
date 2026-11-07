use orchestration_core::run::{Run, RunStatus, RunStep, StepStatus};
use orchestration_core::run_lifecycle::{
    RunProblem, apply_step_status, derive_run_status, is_run_finished,
};
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::json;

use crate::entity_strategies::ordinary_timestamp;
use crate::run_fixtures::run_with_steps;
use crate::workflow_strategies::{run_steps, step_status};

const STATUS_COUNT: usize = 6;
const FINAL_RUN_WIRE_NAMES: [&str; 3] = ["done", "failed", "cancelled"];
const FINAL_RUN_STATUSES: [RunStatus; 3] =
    [RunStatus::Done, RunStatus::Failed, RunStatus::Cancelled];
const ALL_STEP_STATUSES: [StepStatus; 7] = [
    StepStatus::Waiting,
    StepStatus::Running,
    StepStatus::WaitingForApproval,
    StepStatus::WaitingForPerson,
    StepStatus::Done,
    StepStatus::Failed,
    StepStatus::Skipped,
];
const FINISHED_STEP_STATUSES: [StepStatus; 2] =
    [StepStatus::Done, StepStatus::Skipped];
const IN_PROGRESS_STEP_STATUSES: [StepStatus; 5] = [
    StepStatus::Waiting,
    StepStatus::Running,
    StepStatus::WaitingForPerson,
    StepStatus::Done,
    StepStatus::Skipped,
];
const UNBLOCKED_STEP_STATUSES: [StepStatus; 4] = [
    StepStatus::Waiting,
    StepStatus::Running,
    StepStatus::WaitingForPerson,
    StepStatus::Done,
];

fn run_status() -> impl Strategy<Value = RunStatus> {
    prop_oneof![
        Just(RunStatus::Queued),
        Just(RunStatus::Running),
        Just(RunStatus::WaitingForApproval),
        Just(RunStatus::Failed),
        Just(RunStatus::Cancelled),
        Just(RunStatus::Done),
    ]
}

fn relabel(steps: &[RunStep], statuses: &[StepStatus]) -> Vec<RunStep> {
    let mut relabelled = Vec::new();
    for (step, status) in steps.iter().zip(statuses) {
        relabelled.push(RunStep {
            status: *status,
            ..step.clone()
        });
    }
    relabelled
}

fn steps_among(
    choices: &'static [StepStatus],
) -> impl Strategy<Value = Vec<RunStep>> {
    let statuses = vec(prop::sample::select(choices), STATUS_COUNT);
    (run_steps(), statuses)
        .prop_map(|(steps, statuses)| relabel(&steps, &statuses))
        .prop_filter("some steps", |steps| !steps.is_empty())
}

fn insert_step_with_status(
    steps: &[RunStep],
    position: prop::sample::Index,
    status: StepStatus,
) -> Vec<RunStep> {
    let mut changed_steps = steps.to_vec();
    let index = position.index(steps.len() + 1);
    changed_steps.insert(
        index,
        RunStep {
            name: "inserted".to_owned(),
            status,
            ..steps[0].clone()
        },
    );
    changed_steps
}

fn is_step_final(status: StepStatus) -> bool {
    matches!(status, StepStatus::Done | StepStatus::Skipped)
}

proptest! {
    #[test]
    fn test_derive_run_status_property_finished_steps_finish_the_run(
        steps in steps_among(&FINISHED_STEP_STATUSES),
    ) {
        prop_assert_eq!(derive_run_status(&steps), RunStatus::Done);
    }

    #[test]
    fn test_derive_run_status_property_untouched_steps_keep_it_queued(
        steps in steps_among(&[StepStatus::Waiting]),
    ) {
        prop_assert_eq!(derive_run_status(&steps), RunStatus::Queued);
    }

    #[test]
    fn test_derive_run_status_property_work_in_progress_is_running(
        steps in steps_among(&IN_PROGRESS_STEP_STATUSES),
    ) {
        let all_waiting = steps
            .iter()
            .all(|step| step.status == StepStatus::Waiting);
        let all_final = steps.iter().all(|step| is_step_final(step.status));
        prop_assume!(!all_waiting && !all_final);

        prop_assert_eq!(derive_run_status(&steps), RunStatus::Running);
    }

    #[test]
    fn test_is_run_finished_property_exactly_the_final_statuses(
        status in run_status(),
    ) {
        let wire_name = serde_json::to_value(status).ok();

        let is_final = FINAL_RUN_WIRE_NAMES
            .iter()
            .any(|name| wire_name == Some(json!(name)));
        prop_assert_eq!(is_run_finished(status), is_final);
    }

    #[test]
    fn test_is_run_finished_property_finished_runs_refuse_step_changes(
        steps in run_steps(),
        status in prop::sample::select(&FINAL_RUN_STATUSES[..]),
        step_status in step_status(),
        step_name in "step-[0-9]",
        at in ordinary_timestamp(),
    ) {
        let run = Run { status, ..run_with_steps(steps) };

        let changed = apply_step_status(&run, &step_name, step_status, at);

        prop_assert_eq!(changed, Err(RunProblem::RunAlreadyFinished));
    }

    #[test]
    fn test_is_run_finished_property_derived_runs_finish_with_their_steps(
        steps in steps_among(&ALL_STEP_STATUSES),
    ) {
        let derived = derive_run_status(&steps);

        let has_failure = steps
            .iter()
            .any(|step| step.status == StepStatus::Failed);
        let all_final = steps.iter().all(|step| is_step_final(step.status));
        prop_assert_eq!(is_run_finished(derived), has_failure || all_final);
    }

    #[test]
    fn test_has_step_with_status_property_one_failure_fails_the_run(
        steps in steps_among(&IN_PROGRESS_STEP_STATUSES),
        position in any::<prop::sample::Index>(),
        other_status in step_status(),
    ) {
        let mixed_steps =
            insert_step_with_status(&steps, position, other_status);
        let failed = StepStatus::Failed;
        let failing_steps =
            insert_step_with_status(&mixed_steps, position, failed);

        prop_assert_eq!(derive_run_status(&failing_steps), RunStatus::Failed);
    }

    #[test]
    fn test_has_step_with_status_property_one_approval_holds_the_run(
        steps in steps_among(&IN_PROGRESS_STEP_STATUSES),
        position in any::<prop::sample::Index>(),
    ) {
        let waiting_steps = insert_step_with_status(
            &steps,
            position,
            StepStatus::WaitingForApproval,
        );

        let derived = derive_run_status(&waiting_steps);

        prop_assert_eq!(derived, RunStatus::WaitingForApproval);
    }

    #[test]
    fn test_has_step_with_status_property_absent_statuses_never_count(
        steps in steps_among(&UNBLOCKED_STEP_STATUSES),
    ) {
        let derived = derive_run_status(&steps);

        prop_assert_ne!(derived, RunStatus::Failed);
        prop_assert_ne!(derived, RunStatus::WaitingForApproval);
    }
}
