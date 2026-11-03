use std::fs;
use std::io;
use std::path::Path;

use crate::agents_file::{AGENTS_FILE_NAME, AgentsFileError};
use crate::git_command::run_git;
use crate::run_error::RunError;

const COMMITTED_REVISION: &str = "HEAD";

pub(crate) async fn restore_project_agents_file(
    worktree: &Path,
) -> Result<(), RunError> {
    let tracked_listing = run_git(
        worktree,
        &[
            "ls-tree",
            "--name-only",
            COMMITTED_REVISION,
            "--",
            AGENTS_FILE_NAME,
        ],
    )
    .await?;
    if tracked_listing.trim().is_empty() {
        return remove_written_agents_file(worktree);
    }

    run_git(
        worktree,
        &["checkout", COMMITTED_REVISION, "--", AGENTS_FILE_NAME],
    )
    .await?;
    Ok(())
}

fn remove_written_agents_file(worktree: &Path) -> Result<(), RunError> {
    let path = worktree.join(AGENTS_FILE_NAME);
    match fs::remove_file(&path) {
        Ok(()) => Ok(()),
        Err(problem) if problem.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(source) => Err(AgentsFileError::Access { path, source }.into()),
    }
}
