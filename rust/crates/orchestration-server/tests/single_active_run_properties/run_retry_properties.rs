use orchestration_core::run::Run;
use orchestration_core::run_lifecycle::is_run_stopped;
use proptest::prelude::*;

use crate::active_run_desk::{
    ObservedAction, RunAction, count_active_runs, is_accepted,
    is_refused_as_running, open_desk, run_actions_strategy,
    work_kind_strategy,
};

const RETRY_CASES: u32 = 16;

fn chosen_retry_run(observed: &ObservedAction) -> Option<&Run> {
    let RunAction::Retry { run_choice } = observed.action else {
        return None;
    };
    let runs = &observed.runs_before;
    if runs.is_empty() {
        return None;
    }
    Some(&runs[run_choice % runs.len()])
}

fn retries_of_stopped_runs(
    observed: &[ObservedAction],
) -> Vec<(&ObservedAction, &Run)> {
    let mut retries = Vec::new();
    for step in observed {
        let Some(chosen_run) = chosen_retry_run(step) else {
            continue;
        };
        if is_run_stopped(chosen_run.status) {
            retries.push((step, chosen_run));
        }
    }
    retries
}

fn with_retries(actions: Vec<RunAction>) -> Vec<RunAction> {
    let mut mixed = Vec::new();
    for action in actions {
        mixed.push(action);
        mixed.push(RunAction::Retry { run_choice: 0 });
    }
    mixed
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RETRY_CASES))]

    #[test]
    fn test_retry_stored_run_property_retries_exactly_when_none_is_active(
        actions in run_actions_strategy().prop_map(with_retries),
        kind in work_kind_strategy(),
    ) {
        let desk = open_desk(kind.schedule());

        let observed = desk.perform_all(&actions);

        for (step, chosen_run) in retries_of_stopped_runs(&observed) {
            let Some(response) = &step.response else {
                return Err(TestCaseError::fail("a retry always answers"));
            };
            let was_idle = count_active_runs(&step.runs_before) == 0;
            prop_assert_eq!(is_accepted(response), was_idle, "{:?}", step);
            let retried = step
                .runs_after
                .iter()
                .find(|run| run.id == chosen_run.id);
            let is_reopened =
                retried.is_some_and(|run| !is_run_stopped(run.status));
            prop_assert_eq!(is_reopened, was_idle);
        }
    }

    #[test]
    fn test_retry_stored_run_property_a_refused_retry_keeps_every_run(
        actions in run_actions_strategy().prop_map(with_retries),
        kind in work_kind_strategy(),
    ) {
        let desk = open_desk(kind.schedule());

        let observed = desk.perform_all(&actions);

        for (step, _chosen_run) in retries_of_stopped_runs(&observed) {
            let Some(response) = &step.response else {
                return Err(TestCaseError::fail("a retry always answers"));
            };
            if is_accepted(response) {
                continue;
            }
            prop_assert_eq!(&step.runs_after, &step.runs_before);
            prop_assert_eq!(&step.task_after, &step.task_before);
        }
    }

    #[test]
    fn test_retry_stored_run_property_the_refusal_names_the_running_kind(
        actions in run_actions_strategy().prop_map(with_retries),
        kind in work_kind_strategy(),
    ) {
        let desk = open_desk(kind.schedule());

        let observed = desk.perform_all(&actions);

        for (step, _chosen_run) in retries_of_stopped_runs(&observed) {
            let Some(response) = &step.response else {
                return Err(TestCaseError::fail("a retry always answers"));
            };
            let was_idle = count_active_runs(&step.runs_before) == 0;
            if !was_idle {
                prop_assert!(
                    is_refused_as_running(response, kind),
                    "{:?}",
                    step
                );
            }
        }
    }
}
