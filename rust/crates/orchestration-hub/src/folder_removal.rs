use std::fs;
use std::io;
use std::path::Path;

use crate::worktrees::WorktreeError;

pub(crate) fn is_real_folder(path: &Path) -> bool {
    fs::symlink_metadata(path).is_ok_and(|metadata| metadata.is_dir())
}

pub(crate) fn remove_folder(folder: &Path) -> Result<(), WorktreeError> {
    match fs::remove_dir_all(folder) {
        Ok(()) => Ok(()),
        Err(problem) if problem.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(source) => Err(WorktreeError::ChangeFolder {
            path: folder.to_path_buf(),
            source,
        }),
    }
}
