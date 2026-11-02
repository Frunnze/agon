use orchestration_api::work::RunAssignment;
use orchestration_hub::clone_source::CloneSource;
use orchestration_hub::worktree_plan::{WorktreeLifetime, WorktreeRequest};

use crate::runner_configuration::WorktreeRoots;

#[must_use]
pub fn describe_worktree_request(
    assignment: &RunAssignment,
    worktree_roots: &WorktreeRoots,
    clone_source: &CloneSource,
) -> WorktreeRequest {
    let task = &assignment.task;
    let lifetime = match task.schedule {
        Some(_) => WorktreeLifetime::PerJobRun {
            run_number: assignment.run.number,
        },
        None => WorktreeLifetime::PerTask,
    };

    let repositories = match &assignment.project {
        Some(project) => project.repositories.clone(),
        None => Vec::new(),
    };

    WorktreeRequest {
        task_id: task.id,
        task_title: task.title.clone(),
        lifetime,
        repositories,
        cache_root: worktree_roots.cache_root.clone(),
        worktrees_root: worktree_roots.worktrees_root.clone(),
        clone_source: clone_source.clone(),
    }
}
