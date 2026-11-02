use chrono::{DateTime, Utc};
use orchestration_core::run::Run;
use orchestration_core::schedule_rules::{describe_schedule, next_run_after};
use orchestration_core::task::Task;
use orchestration_core::task_summary::{
    TaskSummary, describe_task_summary, summarize_tasks,
};
use serde::Serialize;

use super::task_commands::WorkspaceTask;
use crate::node_error::NodeError;
use crate::views::{RunProgress, describe_run_progress, find_latest_run};

#[derive(Debug, Serialize)]
pub(super) struct TaskView {
    task: Task,
    project_name: String,
    latest_run: Option<RunProgress>,
}

#[derive(Debug, Serialize)]
pub(super) struct TasksView {
    summary: TaskSummary,
    summary_text: String,
    tasks: Vec<TaskView>,
}

#[derive(Debug, Serialize)]
pub(super) struct JobView {
    task: Task,
    project_name: String,
    schedule_description: String,
    next_run_at: DateTime<Utc>,
    latest_run: Option<RunProgress>,
}

pub(super) fn build_tasks_view(
    workspace_tasks: &[WorkspaceTask],
    runs: &[Run],
) -> TasksView {
    let mut one_time_tasks = Vec::new();
    let mut task_views = Vec::new();
    for workspace_task in workspace_tasks {
        if workspace_task.task.schedule.is_some() {
            continue;
        }
        one_time_tasks.push(workspace_task.task.clone());
        let latest_run = find_latest_run(runs, workspace_task.task.id);
        task_views.push(TaskView {
            task: workspace_task.task.clone(),
            project_name: workspace_task.project_name.clone(),
            latest_run: latest_run.map(describe_run_progress),
        });
    }

    let summary = summarize_tasks(&one_time_tasks);
    TasksView {
        summary,
        summary_text: describe_task_summary(&summary),
        tasks: task_views,
    }
}

pub(super) fn build_job_views(
    workspace_tasks: &[WorkspaceTask],
    runs: &[Run],
    now: DateTime<Utc>,
) -> Result<Vec<JobView>, NodeError> {
    let mut job_views = Vec::new();
    for workspace_task in workspace_tasks {
        let Some(schedule) = workspace_task.task.schedule else {
            continue;
        };
        let latest_run = find_latest_run(runs, workspace_task.task.id);
        job_views.push(JobView {
            task: workspace_task.task.clone(),
            project_name: workspace_task.project_name.clone(),
            schedule_description: describe_schedule(&schedule),
            next_run_at: next_run_after(&schedule, now)?,
            latest_run: latest_run.map(describe_run_progress),
        });
    }
    Ok(job_views)
}
