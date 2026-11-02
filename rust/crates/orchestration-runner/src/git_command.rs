use std::io;
use std::path::Path;

use thiserror::Error;
use tokio::process::Command;

pub(crate) const REMOTE_NAME: &str = "origin";

const GIT_PROGRAM: &str = "git";
const TERMINAL_PROMPT_VARIABLE: &str = "GIT_TERMINAL_PROMPT";
const TERMINAL_PROMPT_DISABLED: &str = "0";
const ARGUMENT_SEPARATOR: &str = " ";

#[derive(Debug, Error)]
pub enum GitError {
    #[error("could not start git: {0}")]
    Start(#[source] io::Error),
    #[error("git {arguments} failed: {output}")]
    Failed { arguments: String, output: String },
}

pub(crate) async fn run_git(
    worktree: &Path,
    arguments: &[&str],
) -> Result<String, GitError> {
    let mut git = Command::new(GIT_PROGRAM);
    git.args(arguments)
        .env(TERMINAL_PROMPT_VARIABLE, TERMINAL_PROMPT_DISABLED)
        .current_dir(worktree);
    let output = git.output().await.map_err(GitError::Start)?;

    if !output.status.success() {
        let problem = String::from_utf8_lossy(&output.stderr);
        return Err(GitError::Failed {
            arguments: arguments.join(ARGUMENT_SEPARATOR),
            output: problem.trim().to_string(),
        });
    }
    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}
