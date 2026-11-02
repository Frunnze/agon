use std::collections::BTreeSet;

use orchestration_api::updates::ChangeTopic;
use orchestration_core::approval::ApprovalRequest;
use orchestration_core::identifiers::{ProjectId, RunId, TaskId};
use orchestration_core::run_lifecycle::is_run_finished;
use orchestration_core::task::TaskPlace;

use crate::events::append_notification;
use crate::scope_cleanup::forget_projects_in_scopes;
use crate::stored_state::StoredState;

const REMOVED_WORK_TOPICS: [ChangeTopic; 4] = [
    ChangeTopic::Tasks,
    ChangeTopic::Approvals,
    ChangeTopic::Skills,
    ChangeTopic::Rules,
];

pub fn has_unfinished_run(
    state: &StoredState,
    task_ids: &BTreeSet<TaskId>,
) -> bool {
    state.runs.values().any(|record| {
        let is_listed = task_ids.contains(&record.run.task_id);
        is_listed && !is_run_finished(record.run.status)
    })
}

pub fn list_project_tasks(
    state: &StoredState,
    project_ids: &BTreeSet<ProjectId>,
) -> BTreeSet<TaskId> {
    state
        .tasks
        .values()
        .filter(|task| is_in_projects(task.place, project_ids))
        .map(|task| task.id)
        .collect()
}

fn is_in_projects(
    place: TaskPlace,
    project_ids: &BTreeSet<ProjectId>,
) -> bool {
    match place {
        TaskPlace::InProject { project_id } => {
            project_ids.contains(&project_id)
        }
        TaskPlace::InWorkspace { .. } => false,
    }
}

pub fn remove_tasks_with_runs(
    state: &mut StoredState,
    task_ids: &BTreeSet<TaskId>,
) {
    let removed_run_ids: BTreeSet<RunId> = state
        .runs
        .values()
        .filter(|record| task_ids.contains(&record.run.task_id))
        .map(|record| record.run.id)
        .collect();

    state
        .runs
        .retain(|run_id, _| !removed_run_ids.contains(run_id));
    state
        .approvals
        .retain(|_, approval| !belongs_to_runs(approval, &removed_run_ids));
    state.tasks.retain(|task_id, _| !task_ids.contains(task_id));
    state
        .job_marks
        .retain(|task_id, _| !task_ids.contains(task_id));
}

pub fn remove_projects_with_work(
    state: &mut StoredState,
    project_ids: &BTreeSet<ProjectId>,
) {
    let task_ids = list_project_tasks(state, project_ids);
    remove_tasks_with_runs(state, &task_ids);
    state
        .projects
        .retain(|project_id, _| !project_ids.contains(project_id));
    forget_projects_in_scopes(state, project_ids);
}

pub fn announce_removed_work(state: &mut StoredState) {
    for topic in REMOVED_WORK_TOPICS {
        append_notification(state, topic);
    }
}

fn belongs_to_runs(
    approval: &ApprovalRequest,
    run_ids: &BTreeSet<RunId>,
) -> bool {
    approval
        .run_id
        .is_some_and(|run_id| run_ids.contains(&run_id))
}
