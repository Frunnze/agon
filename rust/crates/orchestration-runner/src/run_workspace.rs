use std::path::PathBuf;
use std::sync::Arc;

use orchestration_api::work::RunAssignment;
use orchestration_core::agents_markdown::render_agents_markdown;
use orchestration_core::workspace::Repository;
use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::clone_source::CloneSource;
use orchestration_hub::workspace_mounts::WorkspaceMounts;
use orchestration_hub::worktree_plan::{WorktreePlan, plan_worktree};
use orchestration_hub::worktrees::{
    PreparedWorkspace, WorktreeOrigin, create_worktrees,
};
use tokio::task::spawn_blocking;

use crate::agents_file::write_agents_file;
use crate::agents_file_reset::restore_project_agents_file;
use crate::run_error::RunError;
use crate::runner_configuration::WorktreeRoots;
use crate::runner_log::log_task_folder_removal_failure;
use crate::worktree_locks::{SharedWorkingSteps, WorktreeLocks};
use crate::worktree_request::describe_worktree_request;

pub(crate) struct RepositoryCheckout {
    pub(crate) worktree: PathBuf,
    pub(crate) repository: Repository,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum TaskFolderKeeping {
    KeptForTheProject,
    RemovedOnceIdle,
}

pub(crate) struct RunWorkspace {
    pub(crate) branch: String,
    pub(crate) mounts: WorkspaceMounts,
    pub(crate) checkouts: Vec<RepositoryCheckout>,
    pub(crate) working_steps: SharedWorkingSteps,
    pub(crate) task_folder_keeping: TaskFolderKeeping,
}

pub(crate) async fn prepare_run_workspace(
    assignment: &RunAssignment,
    worktree_roots: &WorktreeRoots,
    clone_source: &CloneSource,
    clone_locks: Arc<CloneLocks>,
    worktree_locks: &WorktreeLocks,
) -> Result<RunWorkspace, RunError> {
    let request =
        describe_worktree_request(assignment, worktree_roots, clone_source);
    let plan = plan_worktree(&request)?;
    let working_steps = worktree_locks.working_steps_for(&plan.task_folder);
    let mut steps_in_folder = working_steps.lock().await;
    let prepared =
        create_worktrees_in_background(plan.clone(), clone_locks).await?;

    let rules_markdown = render_project_rules(assignment);
    let mut checkouts = Vec::new();
    let planned_repositories = plan.repositories.iter();
    let prepared_worktrees = prepared.worktrees.iter();
    for ((planned, repository), prepared_worktree) in planned_repositories
        .zip(&request.repositories)
        .zip(prepared_worktrees)
    {
        if prepared_worktree.origin == WorktreeOrigin::Reused {
            restore_project_agents_file(&planned.worktree).await?;
        }
        write_agents_file(&planned.worktree, &rules_markdown)?;
        checkouts.push(RepositoryCheckout {
            worktree: planned.worktree.clone(),
            repository: repository.clone(),
        });
    }
    steps_in_folder.enter();
    drop(steps_in_folder);

    Ok(RunWorkspace {
        branch: plan.branch,
        mounts: prepared.mounts,
        checkouts,
        working_steps,
        task_folder_keeping: choose_task_folder_keeping(assignment),
    })
}

pub(crate) fn remove_idle_task_folder(workspace: &RunWorkspace) {
    if workspace.task_folder_keeping == TaskFolderKeeping::KeptForTheProject {
        return;
    }
    let removal = std::fs::remove_dir_all(&workspace.mounts.task_folder);
    if let Err(problem) = removal {
        log_task_folder_removal_failure(&problem);
    }
}

fn choose_task_folder_keeping(
    assignment: &RunAssignment,
) -> TaskFolderKeeping {
    if assignment.project.is_some() {
        return TaskFolderKeeping::KeptForTheProject;
    }
    TaskFolderKeeping::RemovedOnceIdle
}

fn render_project_rules(assignment: &RunAssignment) -> String {
    let Some(project) = &assignment.project else {
        return String::new();
    };
    render_agents_markdown(&assignment.rules, project.workspace_id, project.id)
}

async fn create_worktrees_in_background(
    plan: WorktreePlan,
    clone_locks: Arc<CloneLocks>,
) -> Result<PreparedWorkspace, RunError> {
    let creation =
        spawn_blocking(move || create_worktrees(&plan, &clone_locks));
    Ok(creation.await??)
}
