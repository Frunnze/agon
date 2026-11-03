use std::path::PathBuf;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct WorktreeRoots {
    pub cache_root: PathBuf,
    pub worktrees_root: PathBuf,
}
