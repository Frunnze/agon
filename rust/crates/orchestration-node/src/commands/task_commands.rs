use chrono::Utc;
use orchestration_api::work::{SaveTaskRequest, TaskStart, UpdateTaskRequest};
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{
    ProjectId, SkillId, TaskId, WorkspaceId, generate_uuid,
};
use orchestration_core::schedule_rules::next_run_after;
use orchestration_core::task::{
    Schedule, Task, TaskDoer, TaskPlace, TaskStatus,
};
use serde::Deserialize;
use serde_json::Value;

use super::project_commands::find_project;
use super::task_views::{build_job_views, build_tasks_view};
use crate::command_reply::encode_reply;
use crate::content_sealing::{open_run, open_task, seal_task};
use crate::node::{DeviceSession, Node};
use crate::node_error::NodeError;
use crate::server_client::SignedServerClient;

pub(super) const TASK_COMMAND_NAMES: [&str; 7] = [
    "list_tasks",
    "create_task",
    "update_task",
    "list_jobs",
    "create_job",
    "update_job",
    "start_task",
];

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct TaskArguments {
    workspace_id: WorkspaceId,
    project_id: ProjectId,
    title: String,
    details: String,
    doer: TaskDoer,
    runs_on: RunnerTarget,
    skills: Vec<SkillId>,
    uses_automatic_skills: bool,
    approval_policy: ApprovalPolicy,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum TaskCommand {
    ListTasks {
        workspace_id: WorkspaceId,
    },
    CreateTask {
        task: TaskArguments,
        start: TaskStart,
    },
    UpdateTask {
        task_id: TaskId,
        task: TaskArguments,
    },
    ListJobs {
        workspace_id: WorkspaceId,
    },
    CreateJob {
        task: TaskArguments,
        schedule: Schedule,
    },
    UpdateJob {
        task_id: TaskId,
        task: TaskArguments,
        schedule: Schedule,
    },
    StartTask {
        task_id: TaskId,
    },
}

pub(super) async fn handle_task_command(
    node: &Node,
    command: TaskCommand,
) -> Result<Value, NodeError> {
    let session = node.open_session()?;
    let client = session.client();
    match command {
        TaskCommand::ListTasks { workspace_id } => {
            let tasks =
                list_workspace_tasks(&session, &client, workspace_id).await?;
            let runs = client.list_runs().await?;
            encode_reply(&build_tasks_view(&tasks, &runs))
        }
        TaskCommand::CreateTask { task, start } => {
            let workspace_id = task.workspace_id;
            let new_task = build_task(task, None);
            queue_task(&session, &client, workspace_id, &new_task, start)
                .await?;
            encode_reply(&new_task)
        }
        TaskCommand::ListJobs { workspace_id } => {
            let tasks =
                list_workspace_tasks(&session, &client, workspace_id).await?;
            let runs = client.list_runs().await?;
            encode_reply(&build_job_views(&tasks, &runs, Utc::now())?)
        }
        TaskCommand::CreateJob { task, schedule } => {
            next_run_after(&schedule, Utc::now())?;
            let workspace_id = task.workspace_id;
            let new_job = build_task(task, Some(schedule));
            queue_task(
                &session,
                &client,
                workspace_id,
                &new_job,
                TaskStart::Later,
            )
            .await?;
            encode_reply(&new_job)
        }
        TaskCommand::UpdateTask { task_id, task } => {
            let workspace_id = task.workspace_id;
            let changed = Task {
                id: task_id,
                ..build_task(task, None)
            };
            let stored =
                replace_task(&session, &client, workspace_id, &changed)
                    .await?;
            encode_reply(&stored)
        }
        TaskCommand::UpdateJob {
            task_id,
            task,
            schedule,
        } => {
            next_run_after(&schedule, Utc::now())?;
            let workspace_id = task.workspace_id;
            let changed = Task {
                id: task_id,
                ..build_task(task, Some(schedule))
            };
            let stored =
                replace_task(&session, &client, workspace_id, &changed)
                    .await?;
            encode_reply(&stored)
        }
        TaskCommand::StartTask { task_id } => {
            let run = client.start_task(task_id).await?;
            encode_reply(&open_run(&session.keyring, &run)?)
        }
    }
}

pub(super) struct WorkspaceTask {
    pub(super) task: Task,
    pub(super) project_name: String,
}

async fn list_workspace_tasks(
    session: &DeviceSession,
    client: &SignedServerClient<'_>,
    workspace_id: WorkspaceId,
) -> Result<Vec<WorkspaceTask>, NodeError> {
    let projects = client.list_projects().await?;
    let mut workspace_tasks = Vec::new();
    for task in client.list_tasks().await? {
        let TaskPlace::InProject { project_id } = task.place else {
            continue;
        };
        let project = projects.iter().find(|project| {
            project.id == project_id && project.workspace_id == workspace_id
        });
        if let Some(project) = project {
            workspace_tasks.push(WorkspaceTask {
                task: open_task(&session.keyring, &task)?,
                project_name: project.name.clone(),
            });
        }
    }
    Ok(workspace_tasks)
}

fn build_task(arguments: TaskArguments, schedule: Option<Schedule>) -> Task {
    Task {
        id: TaskId(generate_uuid()),
        title: arguments.title,
        details: arguments.details,
        place: TaskPlace::InProject {
            project_id: arguments.project_id,
        },
        doer: arguments.doer,
        runs_on: arguments.runs_on,
        skills: arguments.skills,
        uses_automatic_skills: arguments.uses_automatic_skills,
        approval_policy: arguments.approval_policy,
        schedule,
        status: TaskStatus::ToDo,
        created_at: Utc::now(),
    }
}

pub(super) async fn queue_task(
    session: &DeviceSession,
    client: &SignedServerClient<'_>,
    workspace_id: WorkspaceId,
    task: &Task,
    start: TaskStart,
) -> Result<(), NodeError> {
    let request = SaveTaskRequest {
        task: prepare_task_upload(session, client, workspace_id, task).await?,
        start,
    };
    client.save_task(&request).await
}

async fn replace_task(
    session: &DeviceSession,
    client: &SignedServerClient<'_>,
    workspace_id: WorkspaceId,
    task: &Task,
) -> Result<Task, NodeError> {
    let request = UpdateTaskRequest {
        task: prepare_task_upload(session, client, workspace_id, task).await?,
    };
    let stored = client.update_task(task.id, &request).await?;
    open_task(&session.keyring, &stored)
}

async fn prepare_task_upload(
    session: &DeviceSession,
    client: &SignedServerClient<'_>,
    workspace_id: WorkspaceId,
    task: &Task,
) -> Result<Task, NodeError> {
    if task.title.trim().is_empty() {
        return Err(NodeError::EmptyText {
            field: "task title",
        });
    }
    if let TaskPlace::InProject { project_id } = task.place {
        let projects = client.list_projects().await?;
        let project = find_project(&projects, project_id)?;
        if project.workspace_id != workspace_id {
            return Err(NodeError::ProjectOutsideWorkspace {
                project: project.id.0,
                workspace: workspace_id.0,
            });
        }
    }

    let workspace_key = session.keyring.key_for(workspace_id)?;
    seal_task(workspace_key, task)
}
