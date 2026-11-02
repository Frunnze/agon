use std::collections::BTreeSet;

use axum::Json;
use axum::extract::State;
use orchestration_api::catalog::{
    AddRepositoryRequest, RemoveRepositoryRequest, SaveProjectRequest,
};
use orchestration_api::updates::ChangeTopic;
use orchestration_core::identifiers::{DeviceId, ProjectId};
use orchestration_core::local_folders::find_folder_device;
use orchestration_core::naming::validate_name;
use orchestration_core::repository_address::parse_repository_address;
use orchestration_core::workspace::{Project, Repository};
use uuid::Uuid;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::error::ServerError;
use crate::extractors::{PathValue, parse_json_body};
use crate::memberships::require_workspace_member;
use crate::server::SharedServer;
use crate::stored_state::StoredState;

pub async fn list_projects(
    State(server): State<SharedServer>,
    _request: SignedRequest,
) -> Result<Json<Vec<Project>>, ServerError> {
    let projects =
        server.read(|state| Ok(state.projects.values().cloned().collect()))?;
    Ok(Json(projects))
}

pub async fn save_project(
    State(server): State<SharedServer>,
    request: SignedRequest,
) -> Result<Json<Project>, ServerError> {
    request.caller.require_client()?;
    let save_request: SaveProjectRequest = parse_json_body(&request.body)?;
    let caller_id = &request.caller.device_id;
    let project = server.apply(caller_id, |state, _now| {
        store_project(state, caller_id, &save_request.project)
    })?;
    Ok(Json(project))
}

pub async fn add_repository(
    State(server): State<SharedServer>,
    PathValue(project_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Project>, ServerError> {
    request.caller.require_client()?;
    let add_request: AddRepositoryRequest = parse_json_body(&request.body)?;
    let project_id = ProjectId(project_uuid);
    let caller_id = &request.caller.device_id;
    let project = server.apply(caller_id, |state, _now| {
        append_repository(state, caller_id, project_id, &add_request)
    })?;
    Ok(Json(project))
}

pub async fn remove_repository(
    State(server): State<SharedServer>,
    PathValue(project_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Project>, ServerError> {
    request.caller.require_client()?;
    let remove_request: RemoveRepositoryRequest =
        parse_json_body(&request.body)?;
    let project_id = ProjectId(project_uuid);
    let caller_id = &request.caller.device_id;
    let project = server.apply(caller_id, |state, _now| {
        drop_repository(state, caller_id, project_id, &remove_request.address)
    })?;
    Ok(Json(project))
}

fn drop_repository(
    state: &mut StoredState,
    caller_id: &DeviceId,
    project_id: ProjectId,
    address: &str,
) -> Result<Change<Project>, ServerError> {
    let project = state
        .projects
        .get(&project_id)
        .ok_or(ServerError::NotFound("the project"))?;
    require_workspace_member(state, caller_id, project.workspace_id)?;
    let canonical_address = parse_repository_address(address)?;
    let mut repositories = project.repositories.clone();
    let listed_count = repositories.len();
    repositories.retain(|listed| listed.address != canonical_address);
    if repositories.len() == listed_count {
        return Err(ServerError::NotFound("the repository"));
    }

    let changed_project = Project {
        repositories,
        ..project.clone()
    };
    state.projects.insert(project_id, changed_project.clone());
    let event_text = format!(
        "Removed repository {canonical_address} from {}",
        changed_project.name
    );
    Ok(Change::recorded(
        changed_project,
        ChangeTopic::Projects,
        event_text,
    ))
}

fn store_project(
    state: &mut StoredState,
    caller_id: &DeviceId,
    project: &Project,
) -> Result<Change<Project>, ServerError> {
    validate_name(&project.name)?;
    if !state.workspaces.contains_key(&project.workspace_id) {
        return Err(ServerError::NotFound("the workspace"));
    }
    require_workspace_member(state, caller_id, project.workspace_id)?;
    let repositories = normalise_repositories(&project.repositories)?;

    let stored_project = Project {
        repositories,
        ..project.clone()
    };
    state
        .projects
        .insert(stored_project.id, stored_project.clone());
    let event_text = format!("Saved project {}", stored_project.name);
    Ok(Change::recorded(
        stored_project,
        ChangeTopic::Projects,
        event_text,
    ))
}

fn append_repository(
    state: &mut StoredState,
    caller_id: &DeviceId,
    project_id: ProjectId,
    request: &AddRepositoryRequest,
) -> Result<Change<Project>, ServerError> {
    let repository = normalise_repository(&request.repository)?;
    let project = state
        .projects
        .get(&project_id)
        .ok_or(ServerError::NotFound("the project"))?;
    require_workspace_member(state, caller_id, project.workspace_id)?;
    let is_listed = project
        .repositories
        .iter()
        .any(|listed| listed.address == repository.address);
    if is_listed {
        return Err(ServerError::Conflict(format!(
            "the project already has {}",
            repository.address
        )));
    }

    let mut repositories = project.repositories.clone();
    repositories.push(repository.clone());
    find_folder_device(&repositories)?;
    let changed_project = Project {
        repositories,
        ..project.clone()
    };
    state.projects.insert(project_id, changed_project.clone());
    let event_text = format!(
        "Added repository {} to {}",
        repository.address, changed_project.name
    );
    Ok(Change::recorded(
        changed_project,
        ChangeTopic::Projects,
        event_text,
    ))
}

fn normalise_repositories(
    repositories: &[Repository],
) -> Result<Vec<Repository>, ServerError> {
    let mut seen_addresses = BTreeSet::new();
    let mut normalised = Vec::new();
    for repository in repositories {
        let canonical = normalise_repository(repository)?;
        if !seen_addresses.insert(canonical.address.clone()) {
            return Err(ServerError::Invalid(format!(
                "the project lists {} twice",
                canonical.address
            )));
        }
        normalised.push(canonical);
    }
    find_folder_device(&normalised)?;
    Ok(normalised)
}

fn normalise_repository(
    repository: &Repository,
) -> Result<Repository, ServerError> {
    let address = parse_repository_address(&repository.address)?;
    Ok(Repository {
        address,
        ..repository.clone()
    })
}
