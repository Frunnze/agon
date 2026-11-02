use serde::{Deserialize, Serialize};

use crate::task::{Task, TaskStatus};

const PART_SEPARATOR: &str = " · ";
const NO_TASKS_TEXT: &str = "No tasks yet";
const ALL_DONE_TEXT: &str = "All done";

#[derive(
    Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize,
)]
pub struct TaskSummary {
    pub to_do: usize,
    pub running: usize,
    pub waiting_for_approval: usize,
    pub failed: usize,
    pub done: usize,
}

#[must_use]
pub fn summarize_tasks(tasks: &[Task]) -> TaskSummary {
    TaskSummary {
        to_do: count_tasks_with_status(tasks, TaskStatus::ToDo),
        running: count_tasks_with_status(tasks, TaskStatus::Running),
        waiting_for_approval: count_tasks_with_status(
            tasks,
            TaskStatus::WaitingForApproval,
        ),
        failed: count_tasks_with_status(tasks, TaskStatus::Failed),
        done: count_tasks_with_status(tasks, TaskStatus::Done),
    }
}

#[must_use]
pub fn describe_task_summary(summary: &TaskSummary) -> String {
    let labelled_counts = [
        (summary.running, "running"),
        (summary.waiting_for_approval, "waiting for approval"),
        (summary.failed, "failed"),
        (summary.to_do, "to do"),
    ];
    let mut parts: Vec<String> = Vec::new();
    for (count, label) in labelled_counts {
        if count > 0 {
            parts.push(format!("{count} {label}"));
        }
    }

    if !parts.is_empty() {
        return parts.join(PART_SEPARATOR);
    }
    if summary.done > 0 {
        return ALL_DONE_TEXT.to_owned();
    }
    NO_TASKS_TEXT.to_owned()
}

fn count_tasks_with_status(tasks: &[Task], status: TaskStatus) -> usize {
    tasks.iter().filter(|task| task.status == status).count()
}
