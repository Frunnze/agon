use orchestration_core::identifiers::{ProjectId, WorkspaceId};
use orchestration_core::task::{Task, TaskPlace};
use orchestration_core::workspace::Project;

use crate::error::ServerError;
use crate::stored_state::StoredState;

pub fn find_task_workspace(
    state: &StoredState,
    task: &Task,
) -> Result<WorkspaceId, ServerError> {
    match task.place {
        TaskPlace::InProject { project_id } => {
            let project = find_project(state, project_id)?;
            Ok(project.workspace_id)
        }
        TaskPlace::InWorkspace { workspace_id } => {
            if !state.workspaces.contains_key(&workspace_id) {
                return Err(ServerError::NotFound("the workspace"));
            }
            Ok(workspace_id)
        }
    }
}

pub fn find_task_project<'state>(
    state: &'state StoredState,
    task: &Task,
) -> Result<Option<&'state Project>, ServerError> {
    match task.place {
        TaskPlace::InProject { project_id } => {
            Ok(Some(find_project(state, project_id)?))
        }
        TaskPlace::InWorkspace { .. } => Ok(None),
    }
}

fn find_project(
    state: &StoredState,
    project_id: ProjectId,
) -> Result<&Project, ServerError> {
    state
        .projects
        .get(&project_id)
        .ok_or(ServerError::NotFound("the project"))
}
