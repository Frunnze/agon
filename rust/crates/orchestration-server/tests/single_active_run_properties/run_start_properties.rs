use orchestration_core::task::TaskStatus;
use proptest::prelude::*;

use crate::active_run_desk::{
    ObservedAction, RunAction, count_active_runs, is_accepted,
    is_refused_as_running, open_desk, run_actions_strategy,
    work_kind_strategy,
};

const START_CASES: u32 = 16;

fn is_start(action: RunAction) -> bool {
    matches!(action, RunAction::Start | RunAction::SaveAndStart)
}

fn highest_run_number(observed: &ObservedAction) -> u32 {
    let mut highest_number = 0;
    for run in &observed.runs_before {
        highest_number = highest_number.max(run.number);
    }
    highest_number
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(START_CASES))]

    #[test]
    fn test_start_run_property_a_task_never_has_two_active_runs(
        actions in run_actions_strategy(),
        kind in work_kind_strategy(),
    ) {
        let desk = open_desk(kind.schedule());

        let observed = desk.perform_all(&actions);

        for step in &observed {
            prop_assert!(
                count_active_runs(&step.runs_after) <= 1,
                "{:?}",
                step
            );
        }
    }

    #[test]
    fn test_start_run_property_starts_exactly_when_no_run_is_active(
        actions in run_actions_strategy(),
        kind in work_kind_strategy(),
    ) {
        let desk = open_desk(kind.schedule());

        let observed = desk.perform_all(&actions);

        for step in observed.iter().filter(|step| is_start(step.action)) {
            let Some(response) = &step.response else {
                return Err(TestCaseError::fail("a start always answers"));
            };
            let was_idle = count_active_runs(&step.runs_before) == 0;
            prop_assert_eq!(is_accepted(response), was_idle, "{:?}", step);
            if was_idle {
                let added_count =
                    step.runs_after.len() - step.runs_before.len();
                prop_assert_eq!(added_count, 1);
                let newest_run = step.runs_after.last();
                let newest_number = newest_run.map(|run| run.number);
                prop_assert_eq!(
                    newest_number,
                    Some(highest_run_number(step) + 1)
                );
            }
        }
    }

    #[test]
    fn test_start_run_property_a_refused_start_names_the_kind_and_keeps_all(
        actions in run_actions_strategy(),
        kind in work_kind_strategy(),
    ) {
        let desk = open_desk(kind.schedule());

        let observed = desk.perform_all(&actions);

        for step in observed.iter().filter(|step| is_start(step.action)) {
            let Some(response) = &step.response else {
                return Err(TestCaseError::fail("a start always answers"));
            };
            if is_accepted(response) {
                continue;
            }
            let is_refused = is_refused_as_running(response, kind);
            prop_assert!(is_refused, "{:?}", step);
            prop_assert_eq!(&step.runs_after, &step.runs_before);
            prop_assert_eq!(&step.task_after, &step.task_before);
            prop_assert_eq!(step.task_after.status, TaskStatus::Running);
        }
    }
}
