use orchestration_core::identifiers::WorkflowId;
use orchestration_core::task::{Task, TaskStatus};
use orchestration_core::task_summary::{
    TaskSummary, describe_task_summary, summarize_tasks,
};
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::entity_strategies::{
    one_agent_doer, task_with_doer, workflow_doer,
};

const MAXIMUM_TASKS: usize = 12;
const SEPARATOR: &str = " · ";

fn count_status(tasks: &[Task], status: TaskStatus) -> usize {
    tasks.iter().filter(|task| task.status == status).count()
}

fn task_summary() -> impl Strategy<Value = TaskSummary> {
    (
        any::<usize>(),
        any::<usize>(),
        any::<usize>(),
        any::<usize>(),
        any::<usize>(),
    )
        .prop_map(
            |(to_do, running, waiting_for_approval, failed, done)| {
                TaskSummary {
                    to_do,
                    running,
                    waiting_for_approval,
                    failed,
                    done,
                }
            },
        )
}

fn small_task_summary() -> impl Strategy<Value = TaskSummary> {
    vec(task_with_doer(one_agent_doer()), 0..MAXIMUM_TASKS)
        .prop_map(|tasks| summarize_tasks(&tasks))
}

#[test]
fn test_describe_task_summary_matches_the_tasks_screen() {
    let summary = TaskSummary {
        to_do: 1,
        running: 1,
        waiting_for_approval: 0,
        failed: 1,
        done: 1,
    };

    assert_eq!(
        describe_task_summary(&summary),
        "1 running · 1 failed · 1 to do"
    );
}

#[test]
fn test_describe_task_summary_names_empty_and_finished_lists() {
    let no_tasks = TaskSummary::default();
    let only_done = TaskSummary {
        done: 2,
        ..TaskSummary::default()
    };
    let waiting = TaskSummary {
        waiting_for_approval: 2,
        ..TaskSummary::default()
    };

    assert_eq!(describe_task_summary(&no_tasks), "No tasks yet");
    assert_eq!(describe_task_summary(&only_done), "All done");
    assert_eq!(describe_task_summary(&waiting), "2 waiting for approval");
}

proptest! {
    #[test]
    fn test_summarize_tasks_property_counts_every_task_once(
        tasks in vec(task_with_doer(one_agent_doer()), 0..MAXIMUM_TASKS),
    ) {
        let summary = summarize_tasks(&tasks);

        prop_assert_eq!(summary.to_do, count_status(&tasks, TaskStatus::ToDo));
        prop_assert_eq!(
            summary.running,
            count_status(&tasks, TaskStatus::Running)
        );
        prop_assert_eq!(
            summary.waiting_for_approval,
            count_status(&tasks, TaskStatus::WaitingForApproval)
        );
        prop_assert_eq!(
            summary.failed,
            count_status(&tasks, TaskStatus::Failed)
        );
        prop_assert_eq!(summary.done, count_status(&tasks, TaskStatus::Done));
        let total = summary.to_do
            + summary.running
            + summary.waiting_for_approval
            + summary.failed
            + summary.done;
        prop_assert_eq!(total, tasks.len());
    }

    #[test]
    fn test_summarize_tasks_property_ignores_task_order(
        tasks in vec(task_with_doer(one_agent_doer()), 0..MAXIMUM_TASKS),
    ) {
        let reversed: Vec<Task> = tasks.iter().rev().cloned().collect();

        prop_assert_eq!(summarize_tasks(&tasks), summarize_tasks(&reversed));
    }

    #[test]
    fn test_summarize_tasks_fuzz_any_doer_is_counted(
        tasks in vec(
            prop_oneof![
                task_with_doer(one_agent_doer()),
                task_with_doer(workflow_doer(WorkflowId(Uuid::nil()))),
            ],
            0..MAXIMUM_TASKS,
        ),
    ) {
        let summary = summarize_tasks(&tasks);

        let total = summary.to_do
            + summary.running
            + summary.waiting_for_approval
            + summary.failed
            + summary.done;
        prop_assert_eq!(total, tasks.len());
    }

    #[test]
    fn test_describe_task_summary_property_lists_open_counts_in_order(
        summary in small_task_summary(),
    ) {
        let mut expected_parts: Vec<String> = Vec::new();
        let labelled_counts = [
            (summary.running, "running"),
            (summary.waiting_for_approval, "waiting for approval"),
            (summary.failed, "failed"),
            (summary.to_do, "to do"),
        ];
        for (count, label) in labelled_counts {
            if count > 0 {
                expected_parts.push(format!("{count} {label}"));
            }
        }

        let description = describe_task_summary(&summary);

        if expected_parts.is_empty() {
            prop_assert!(
                description == "No tasks yet" || description == "All done"
            );
            prop_assert_eq!(description == "All done", summary.done > 0);
        } else {
            prop_assert_eq!(description, expected_parts.join(SEPARATOR));
        }
    }

    #[test]
    fn test_describe_task_summary_fuzz_huge_counts_still_read(
        summary in task_summary(),
    ) {
        let description = describe_task_summary(&summary);

        prop_assert!(!description.is_empty());
        prop_assert!(!description.starts_with(SEPARATOR));
        prop_assert!(!description.ends_with(SEPARATOR));
    }
}
