use std::path::Path;

use crate::git_command::{GitError, REMOTE_NAME, run_git};

const REMOTES_OPTION_PREFIX: &str = "--remotes=";

pub async fn list_unpushed_commit_subjects(
    worktree: &Path,
) -> Result<Vec<String>, GitError> {
    let remotes_option = format!("{REMOTES_OPTION_PREFIX}{REMOTE_NAME}");
    let arguments = [
        "log",
        "--reverse",
        "--format=%s",
        "HEAD",
        "--not",
        remotes_option.as_str(),
    ];

    let subjects = run_git(worktree, &arguments).await?;
    let mut commit_subjects = Vec::new();
    for subject in subjects.lines() {
        commit_subjects.push(subject.to_string());
    }
    Ok(commit_subjects)
}
