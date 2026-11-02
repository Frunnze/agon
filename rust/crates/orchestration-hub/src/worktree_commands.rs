use std::collections::BTreeMap;
use std::path::Path;

use crate::command_specification::CommandSpecification;

const GIT_PROGRAM: &str = "git";
const TERMINAL_PROMPT_VARIABLE: &str = "GIT_TERMINAL_PROMPT";
const TERMINAL_PROMPT_DISABLED: &str = "0";
const REMOTE_NAME: &str = "origin";

pub(crate) fn clone_command(
    clone_url: &str,
    cached_clone: &Path,
) -> CommandSpecification {
    let destination = cached_clone.display().to_string();
    git_command(
        None,
        &["clone", "--no-checkout", "--", clone_url, &destination],
    )
}

pub(crate) fn fetch_command(cached_clone: &Path) -> CommandSpecification {
    git_command(Some(cached_clone), &["fetch", "--prune", REMOTE_NAME])
}

pub(crate) fn add_worktree_command(
    cached_clone: &Path,
    branch: &str,
    worktree: &Path,
    default_branch: &str,
) -> CommandSpecification {
    let worktree = worktree.display().to_string();
    let starting_point = format!("{REMOTE_NAME}/{default_branch}");
    git_command(
        Some(cached_clone),
        &["worktree", "add", "-b", branch, &worktree, &starting_point],
    )
}

pub(crate) fn remove_worktree_command(
    cached_clone: &Path,
    worktree: &Path,
) -> CommandSpecification {
    let worktree = worktree.display().to_string();
    git_command(
        Some(cached_clone),
        &["worktree", "remove", "--force", &worktree],
    )
}

pub(crate) fn delete_branch_command(
    cached_clone: &Path,
    branch: &str,
) -> CommandSpecification {
    git_command(Some(cached_clone), &["branch", "-D", branch])
}

fn git_command(
    working_directory: Option<&Path>,
    arguments: &[&str],
) -> CommandSpecification {
    let environment = BTreeMap::from([(
        TERMINAL_PROMPT_VARIABLE.to_string(),
        TERMINAL_PROMPT_DISABLED.to_string(),
    )]);
    CommandSpecification {
        program: GIT_PROGRAM.to_string(),
        arguments: arguments.iter().map(ToString::to_string).collect(),
        environment,
        working_directory: working_directory.map(Path::to_path_buf),
    }
}
