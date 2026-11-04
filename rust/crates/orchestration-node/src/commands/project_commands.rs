use orchestration_api::catalog::{
    AddRepositoryRequest, RemoveRepositoryRequest, SaveProjectRequest,
};
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::identifiers::{
    DeviceId, ProjectId, WorkspaceId, generate_uuid,
};
use orchestration_core::naming::validate_name;
use orchestration_core::repository_address::parse_repository_address;
use orchestration_core::task::{Task, TaskPlace, TaskStatus};
use orchestration_core::workspace::{AgentAccess, Project, Repository};
use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::local_folder_checks::{
    check_local_folder, require_folder_on_this_device,
};
use super::local_folder_creation::create_local_folder;
use crate::command_reply::encode_reply;
use crate::node::Node;
use crate::node_error::NodeError;

pub(super) const PROJECT_COMMAND_NAMES: [&str; 7] = [
    "list_projects",
    "create_project",
    "list_repositories",
    "create_repository",
    "remove_repository",
    "check_local_folder",
    "create_local_folder",
];

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct RepositoryInput {
    address: String,
    default_branch: String,
    agent_access: AgentAccess,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum ProjectCommand {
    ListProjects {
        workspace_id: WorkspaceId,
    },
    CreateProject {
        workspace_id: WorkspaceId,
        name: String,
        repositories: Vec<RepositoryInput>,
        #[serde(default)]
        approval_policy: Option<ApprovalPolicy>,
    },
    ListRepositories {
        project_id: ProjectId,
    },
    CreateRepository {
        project_id: ProjectId,
        repository: RepositoryInput,
    },
    RemoveRepository {
        project_id: ProjectId,
        address: String,
    },
    CheckLocalFolder {
        path: String,
    },
    CreateLocalFolder {
        parent: String,
        name: String,
    },
}

#[derive(Debug, Serialize)]
struct ProjectView {
    project: Project,
    task_count: usize,
    running_task_count: usize,
}

pub(super) async fn handle_project_command(
    node: &Node,
    command: ProjectCommand,
) -> Result<Value, NodeError> {
    let session = node.open_session()?;
    let client = session.client();
    let device_id = session.identity.device_id();
    match command {
        ProjectCommand::ListProjects { workspace_id } => {
            let projects = client.list_projects().await?;
            let tasks = client.list_tasks().await?;
            encode_reply(&build_project_views(&projects, &tasks, workspace_id))
        }
        ProjectCommand::CreateProject {
            workspace_id,
            name,
            repositories,
            approval_policy,
        } => {
            validate_name(&name)?;
            let mut checked_repositories = Vec::new();
            for repository in &repositories {
                let checked = check_repository(repository, &device_id)?;
                checked_repositories.push(checked);
            }
            let project = Project {
                id: ProjectId(generate_uuid()),
                workspace_id,
                name,
                repositories: checked_repositories,
                approval_policy,
            };
            let request = SaveProjectRequest {
                project: project.clone(),
            };
            client.save_project(&request).await?;
            encode_reply(&project)
        }
        ProjectCommand::ListRepositories { project_id } => {
            let projects = client.list_projects().await?;
            let project = find_project(&projects, project_id)?;
            encode_reply(&project.repositories)
        }
        ProjectCommand::CreateRepository {
            project_id,
            repository,
        } => {
            let checked_repository =
                check_repository(&repository, &device_id)?;
            let request = AddRepositoryRequest {
                repository: checked_repository.clone(),
            };
            client.add_repository(project_id, &request).await?;
            encode_reply(&checked_repository)
        }
        ProjectCommand::RemoveRepository {
            project_id,
            address,
        } => {
            let request = RemoveRepositoryRequest {
                address: parse_repository_address(&address)?,
            };
            let project =
                client.remove_repository(project_id, &request).await?;
            encode_reply(&project.repositories)
        }
        ProjectCommand::CheckLocalFolder { path } => {
            encode_reply(&check_local_folder(&device_id, &path)?)
        }
        ProjectCommand::CreateLocalFolder { parent, name } => {
            encode_reply(&create_local_folder(&device_id, &parent, &name)?)
        }
    }
}

pub(super) fn find_project(
    projects: &[Project],
    project_id: ProjectId,
) -> Result<&Project, NodeError> {
    projects
        .iter()
        .find(|project| project.id == project_id)
        .ok_or_else(|| NodeError::NotFound {
            kind: "project",
            identifier: project_id.0.to_string(),
        })
}

fn check_repository(
    repository: &RepositoryInput,
    device_id: &DeviceId,
) -> Result<Repository, NodeError> {
    let default_branch = repository.default_branch.trim();
    if default_branch.is_empty() {
        return Err(NodeError::EmptyText {
            field: "default branch",
        });
    }
    let address = parse_repository_address(&repository.address)?;
    require_folder_on_this_device(device_id, &address)?;
    Ok(Repository {
        address,
        default_branch: default_branch.to_owned(),
        agent_access: repository.agent_access,
    })
}

fn build_project_views(
    projects: &[Project],
    tasks: &[Task],
    workspace_id: WorkspaceId,
) -> Vec<ProjectView> {
    let mut project_views = Vec::new();
    for project in projects {
        if project.workspace_id != workspace_id {
            continue;
        }
        let project_place = TaskPlace::InProject {
            project_id: project.id,
        };
        let project_tasks: Vec<&Task> = tasks
            .iter()
            .filter(|task| task.place == project_place)
            .collect();
        let running_task_count = project_tasks
            .iter()
            .filter(|task| task.status == TaskStatus::Running)
            .count();
        project_views.push(ProjectView {
            project: project.clone(),
            task_count: project_tasks.len(),
            running_task_count,
        });
    }
    project_views
}
