use std::collections::BTreeSet;

use axum::extract::State;
use axum::http::StatusCode;
use orchestration_api::updates::ChangeTopic;
use orchestration_core::identifiers::{
    DeviceId, ProjectId, TaskId, WorkspaceId,
};
use orchestration_core::task::TaskPlace;
use uuid::Uuid;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::error::ServerError;
use crate::events::append_notification;
use crate::extractors::PathValue;
use crate::memberships::{require_workspace_member, withdraw_workspace};
use crate::scope_cleanup::forget_workspace_in_scopes;
use crate::server::SharedServer;
use crate::stored_state::StoredState;
use crate::work_removal::{
    announce_removed_work, has_unfinished_run, list_project_tasks,
    remove_projects_with_work, remove_tasks_with_runs,
};

const LAST_WORKSPACE_COUNT: usize = 1;

pub async fn delete_workspace(
    State(server): State<SharedServer>,
    PathValue(workspace_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<StatusCode, ServerError> {
    request.caller.require_client()?;
    let workspace_id = WorkspaceId(workspace_uuid);
    let caller_id = &request.caller.device_id;
    server.apply(caller_id, |state, _now| {
        drop_workspace(state, caller_id, workspace_id)
    })?;
    Ok(StatusCode::NO_CONTENT)
}

fn drop_workspace(
    state: &mut StoredState,
    caller_id: &DeviceId,
    workspace_id: WorkspaceId,
) -> Result<Change<()>, ServerError> {
    let workspace = state
        .workspaces
        .get(&workspace_id)
        .ok_or(ServerError::NotFound("the workspace"))?
        .clone();
    require_workspace_member(state, caller_id, workspace_id)?;
    if state.workspaces.len() <= LAST_WORKSPACE_COUNT {
        return Err(ServerError::Conflict(
            "the last workspace cannot be deleted".to_owned(),
        ));
    }
    let project_ids = list_workspace_projects(state, workspace_id);
    let task_ids = list_workspace_tasks(state, workspace_id, &project_ids);
    if has_unfinished_run(state, &task_ids) {
        return Err(ServerError::Conflict(format!(
            "a task in workspace {} is running; cancel its run first",
            workspace.name
        )));
    }

    remove_tasks_with_runs(state, &task_ids);
    remove_projects_with_work(state, &project_ids);
    forget_workspace_in_scopes(state, workspace_id);
    let device_ids: Vec<DeviceId> = state.devices.keys().cloned().collect();
    for device_id in &device_ids {
        withdraw_workspace(state, device_id, workspace_id);
    }
    state.workspaces.remove(&workspace_id);

    append_notification(state, ChangeTopic::Projects);
    announce_removed_work(state);
    let event_text = format!("Deleted workspace {}", workspace.name);
    Ok(Change::recorded((), ChangeTopic::Workspaces, event_text))
}

fn list_workspace_projects(
    state: &StoredState,
    workspace_id: WorkspaceId,
) -> BTreeSet<ProjectId> {
    state
        .projects
        .values()
        .filter(|project| project.workspace_id == workspace_id)
        .map(|project| project.id)
        .collect()
}

fn list_workspace_tasks(
    state: &StoredState,
    workspace_id: WorkspaceId,
    project_ids: &BTreeSet<ProjectId>,
) -> BTreeSet<TaskId> {
    let mut task_ids = list_project_tasks(state, project_ids);
    let workspace_place = TaskPlace::InWorkspace { workspace_id };
    for task in state.tasks.values() {
        if task.place == workspace_place {
            task_ids.insert(task.id);
        }
    }
    task_ids
}
