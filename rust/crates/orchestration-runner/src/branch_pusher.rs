use std::path::Path;

use crate::git_command::{GitError, REMOTE_NAME, run_git};

const CHECKED_OUT_COMMIT: &str = "HEAD";
const BRANCH_REFERENCE_PREFIX: &str = "refs/heads/";

pub trait BranchPusher: Send + Sync + 'static {
    fn push_branch(
        &self,
        worktree: &Path,
        branch: &str,
    ) -> impl Future<Output = Result<(), GitError>> + Send;
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct GitBranchPusher;

impl BranchPusher for GitBranchPusher {
    async fn push_branch(
        &self,
        worktree: &Path,
        branch: &str,
    ) -> Result<(), GitError> {
        let refspec =
            format!("{CHECKED_OUT_COMMIT}:{BRANCH_REFERENCE_PREFIX}{branch}");
        run_git(worktree, &["push", REMOTE_NAME, refspec.as_str()]).await?;
        Ok(())
    }
}
