use orchestration_api::work::TaskStart;
use orchestration_core::device::RunnerTarget;
use orchestration_core::task::{TaskPlace, TaskStatus};
use proptest::prelude::*;

use crate::active_run_desk::{
    count_active_runs, is_accepted, open_desk, run_actions_strategy,
    work_kind_strategy,
};
use crate::fixtures::{one_agent_task, save_task};
use crate::test_client::block_on;

const REFUSAL_CASES: u32 = 16;
const ROUND_LIMIT: usize = 6;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REFUSAL_CASES))]

    #[test]
    fn test_refuse_second_active_run_property_stopped_runs_never_block(
        round_count in 1..ROUND_LIMIT,
        kind in work_kind_strategy(),
    ) {
        let desk = open_desk(kind.schedule());

        let outcomes = block_on(async {
            let mut outcomes = Vec::new();
            for _round in 0..round_count {
                let started = desk.start().await;
                let runs = desk.list_runs().await;
                let cancelled = match runs.last() {
                    Some(newest_run) => Some(desk.cancel(newest_run).await),
                    None => None,
                };
                outcomes.push((started, cancelled));
            }
            outcomes
        });
        let runs = block_on(desk.list_runs());

        for (started, cancelled) in &outcomes {
            prop_assert!(is_accepted(started), "{:?}", started);
            prop_assert!(cancelled.as_ref().is_some_and(is_accepted));
        }
        let mut numbers = Vec::new();
        for run in &runs {
            numbers.push(run.number);
        }
        let expected_numbers: Vec<u32> = (1..).take(round_count).collect();
        prop_assert_eq!(numbers, expected_numbers);
    }

    #[test]
    fn test_refuse_second_active_run_property_task_status_follows_runs(
        actions in run_actions_strategy(),
        kind in work_kind_strategy(),
    ) {
        let desk = open_desk(kind.schedule());

        let observed = desk.perform_all(&actions);

        for step in &observed {
            let is_running = count_active_runs(&step.runs_after) == 1;
            let expected_status = if is_running {
                TaskStatus::Running
            } else {
                TaskStatus::ToDo
            };
            prop_assert_eq!(step.task_after.status, expected_status);
        }
    }

    #[test]
    fn test_refuse_second_active_run_property_other_tasks_never_block(
        other_count in 1..ROUND_LIMIT,
        kind in work_kind_strategy(),
    ) {
        let desk = open_desk(kind.schedule());
        let TaskPlace::InProject { project_id } = desk.task.place else {
            return Err(TestCaseError::fail("the desk task is in a project"));
        };

        let outcomes = block_on(async {
            let first_start = desk.start().await;
            let mut other_starts = Vec::new();
            for _other in 0..other_count {
                let other_task = one_agent_task(
                    project_id,
                    RunnerTarget::AnyFreeRunner,
                    kind.schedule(),
                );
                let saved = save_task(
                    &desk.test,
                    &desk.account,
                    other_task,
                    TaskStart::Now,
                )
                .await;
                other_starts.push(saved.run);
            }
            (first_start, other_starts)
        });

        let (first_start, other_starts) = outcomes;
        prop_assert!(is_accepted(&first_start), "{:?}", first_start);
        for other_start in &other_starts {
            prop_assert!(other_start.is_some());
        }
        let runs = block_on(desk.list_runs());
        prop_assert_eq!(count_active_runs(&runs), 1);
    }
}
