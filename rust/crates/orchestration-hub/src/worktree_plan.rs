use std::collections::BTreeSet;
use std::path::{Path, PathBuf};

use orchestration_core::identifiers::TaskId;
use orchestration_core::workspace::Repository;
use thiserror::Error;

use crate::branch_names::{TASK_BRANCH_PREFIX, is_valid_branch_name};
use crate::cached_clones::cached_clone_folder;
use crate::clone_source::{CloneSource, CloneSourceProblem};
use crate::command_specification::CommandSpecification;
use crate::safe_paths::is_plain_absolute_path;
use crate::slugs::slugify;
use crate::worktree_commands::{
    add_worktree_command, clone_command, delete_branch_command, fetch_command,
    remove_worktree_command,
};

const FALLBACK_TITLE_SLUG: &str = "task";
const FALLBACK_REPOSITORY_NAME: &str = "repository";
const ADDRESS_SEPARATORS: [char; 3] = ['/', ':', '\\'];
const GIT_SUFFIX: &str = ".git";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WorktreeLifetime {
    PerTask,
    PerJobRun { run_number: u32 },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct WorktreeRequest {
    pub task_id: TaskId,
    pub task_title: String,
    pub lifetime: WorktreeLifetime,
    pub repositories: Vec<Repository>,
    pub cache_root: PathBuf,
    pub worktrees_root: PathBuf,
    pub clone_source: CloneSource,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RepositoryWorktreePlan {
    pub cached_clone: PathBuf,
    pub worktree: PathBuf,
    pub clone_command: CommandSpecification,
    pub fetch_command: CommandSpecification,
    pub add_worktree_command: CommandSpecification,
    pub remove_worktree_command: CommandSpecification,
    pub delete_branch_command: CommandSpecification,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct WorktreePlan {
    pub task_folder: PathBuf,
    pub branch: String,
    pub repositories: Vec<RepositoryWorktreePlan>,
}

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum WorktreeProblem {
    #[error("the folder {0:?} is not a plain absolute path")]
    UnsafeRoot(PathBuf),
    #[error("the repository address {0:?} is not usable")]
    InvalidRepositoryAddress(String),
    #[error("the default branch {0:?} is not a valid branch name")]
    InvalidDefaultBranch(String),
    #[error("more than one repository is named {0:?}")]
    DuplicateRepositoryName(String),
    #[error("the folder {0:?} is on another computer")]
    FolderOnAnotherDevice(String),
}

pub fn plan_worktree(
    request: &WorktreeRequest,
) -> Result<WorktreePlan, WorktreeProblem> {
    ensure_plain_root(&request.cache_root)?;
    ensure_plain_root(&request.worktrees_root)?;

    let folder_name = name_task_folder(request);
    let task_folder = request.worktrees_root.join(&folder_name);
    let branch = format!("{TASK_BRANCH_PREFIX}{folder_name}");

    let mut repository_names = BTreeSet::new();
    let mut repositories = Vec::new();
    for repository in &request.repositories {
        let clone_url = plan_clone_url(&request.clone_source, repository)?;
        let name = name_repository(&repository.address);
        if !repository_names.insert(name.clone()) {
            return Err(WorktreeProblem::DuplicateRepositoryName(name));
        }

        let cached_clone =
            cached_clone_folder(&request.cache_root, &repository.address);
        let worktree = task_folder.join(&name);
        repositories.push(plan_repository(
            repository,
            &clone_url,
            cached_clone,
            worktree,
            &branch,
        ));
    }

    Ok(WorktreePlan {
        task_folder,
        branch,
        repositories,
    })
}

fn ensure_plain_root(root: &Path) -> Result<(), WorktreeProblem> {
    if !is_plain_absolute_path(root) {
        return Err(WorktreeProblem::UnsafeRoot(root.to_path_buf()));
    }
    Ok(())
}

fn plan_clone_url(
    clone_source: &CloneSource,
    repository: &Repository,
) -> Result<String, WorktreeProblem> {
    let address = &repository.address;
    let clone_url = clone_source
        .clone_url(address)
        .map_err(|problem| explain_clone_problem(problem, address))?;

    if !is_valid_branch_name(&repository.default_branch) {
        return Err(WorktreeProblem::InvalidDefaultBranch(
            repository.default_branch.clone(),
        ));
    }
    Ok(clone_url)
}

fn explain_clone_problem(
    problem: CloneSourceProblem,
    address: &str,
) -> WorktreeProblem {
    match problem {
        CloneSourceProblem::FolderOnAnotherDevice(folder_address) => {
            WorktreeProblem::FolderOnAnotherDevice(folder_address)
        }
        _ => WorktreeProblem::InvalidRepositoryAddress(address.to_owned()),
    }
}

fn name_task_folder(request: &WorktreeRequest) -> String {
    let title_slug = slugify(&request.task_title);
    let readable_part = if title_slug.is_empty() {
        FALLBACK_TITLE_SLUG.to_string()
    } else {
        title_slug
    };
    let task_part = format!("{readable_part}-{}", request.task_id.0.simple());

    match request.lifetime {
        WorktreeLifetime::PerTask => task_part,
        WorktreeLifetime::PerJobRun { run_number } => {
            format!("{task_part}-run-{run_number}")
        }
    }
}

fn name_repository(address: &str) -> String {
    let without_trailing_separators =
        address.trim_end_matches(ADDRESS_SEPARATORS);
    let last_segment = without_trailing_separators
        .rsplit(ADDRESS_SEPARATORS)
        .next()
        .unwrap_or_default();
    let without_suffix = last_segment
        .strip_suffix(GIT_SUFFIX)
        .unwrap_or(last_segment);

    let name = slugify(without_suffix);
    if name.is_empty() {
        return FALLBACK_REPOSITORY_NAME.to_string();
    }
    name
}

fn plan_repository(
    repository: &Repository,
    clone_url: &str,
    cached_clone: PathBuf,
    worktree: PathBuf,
    branch: &str,
) -> RepositoryWorktreePlan {
    RepositoryWorktreePlan {
        clone_command: clone_command(clone_url, &cached_clone),
        fetch_command: fetch_command(&cached_clone),
        add_worktree_command: add_worktree_command(
            &cached_clone,
            branch,
            &worktree,
            &repository.default_branch,
        ),
        remove_worktree_command: remove_worktree_command(
            &cached_clone,
            &worktree,
        ),
        delete_branch_command: delete_branch_command(&cached_clone, branch),
        cached_clone,
        worktree,
    }
}
