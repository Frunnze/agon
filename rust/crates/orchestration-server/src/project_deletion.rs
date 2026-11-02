use std::collections::BTreeSet;

use axum::extract::State;
use axum::http::StatusCode;
use orchestration_api::updates::ChangeTopic;
use orchestration_core::identifiers::{DeviceId, ProjectId};
use uuid::Uuid;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::error::ServerError;
use crate::extractors::PathValue;
use crate::memberships::require_workspace_member;
use crate::server::SharedServer;
use crate::stored_state::StoredState;
use crate::work_removal::{
    announce_removed_work, has_unfinished_run, list_project_tasks,
    remove_projects_with_work,
};

pub async fn delete_project(
    State(server): State<SharedServer>,
    PathValue(project_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<StatusCode, ServerError> {
    request.caller.require_client()?;
    let project_id = ProjectId(project_uuid);
    let caller_id = &request.caller.device_id;
    server.apply(caller_id, |state, _now| {
        drop_project(state, caller_id, project_id)
    })?;
    Ok(StatusCode::NO_CONTENT)
}

fn drop_project(
    state: &mut StoredState,
    caller_id: &DeviceId,
    project_id: ProjectId,
) -> Result<Change<()>, ServerError> {
    let project = state
        .projects
        .get(&project_id)
        .ok_or(ServerError::NotFound("the project"))?
        .clone();
    require_workspace_member(state, caller_id, project.workspace_id)?;
    let project_ids = BTreeSet::from([project_id]);
    let task_ids = list_project_tasks(state, &project_ids);
    if has_unfinished_run(state, &task_ids) {
        return Err(ServerError::Conflict(format!(
            "a task in project {} is running; cancel its run first",
            project.name
        )));
    }

    remove_projects_with_work(state, &project_ids);
    announce_removed_work(state);
    let event_text = format!("Deleted project {}", project.name);
    Ok(Change::recorded((), ChangeTopic::Projects, event_text))
}
