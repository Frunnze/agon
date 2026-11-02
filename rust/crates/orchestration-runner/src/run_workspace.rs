use std::path::PathBuf;
use std::sync::Arc;

use orchestration_api::work::RunAssignment;
use orchestration_core::agents_markdown::render_agents_markdown;
use orchestration_core::workspace::Repository;
use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::clone_source::CloneSource;
use orchestration_hub::workspace_mounts::WorkspaceMounts;
use orchestration_hub::worktree_plan::{WorktreePlan, plan_worktree};
use orchestration_hub::worktrees::{PreparedWorkspace, create_worktrees};
use tokio::task::spawn_blocking;

use crate::agents_file::write_agents_file;
use crate::run_error::RunError;
use crate::runner_configuration::WorktreeRoots;
use crate::worktree_request::describe_worktree_request;

pub(crate) struct RepositoryCheckout {
    pub(crate) worktree: PathBuf,
    pub(crate) repository: Repository,
}

pub(crate) struct RunWorkspace {
    pub(crate) branch: String,
    pub(crate) mounts: WorkspaceMounts,
    pub(crate) checkouts: Vec<RepositoryCheckout>,
}

pub(crate) async fn prepare_run_workspace(
    assignment: &RunAssignment,
    worktree_roots: &WorktreeRoots,
    clone_source: &CloneSource,
    clone_locks: Arc<CloneLocks>,
) -> Result<RunWorkspace, RunError> {
    let request =
        describe_worktree_request(assignment, worktree_roots, clone_source);
    let plan = plan_worktree(&request)?;
    let prepared =
        create_worktrees_in_background(plan.clone(), clone_locks).await?;

    let rules_markdown = render_project_rules(assignment);
    let mut checkouts = Vec::new();
    let planned_repositories = plan.repositories.iter();
    for (planned, repository) in
        planned_repositories.zip(&request.repositories)
    {
        write_agents_file(&planned.worktree, &rules_markdown)?;
        checkouts.push(RepositoryCheckout {
            worktree: planned.worktree.clone(),
            repository: repository.clone(),
        });
    }

    Ok(RunWorkspace {
        branch: plan.branch,
        mounts: prepared.mounts,
        checkouts,
    })
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
