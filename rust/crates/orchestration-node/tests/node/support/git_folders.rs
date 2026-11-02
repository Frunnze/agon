use std::fs;
use std::path::{Path, PathBuf};

use super::test_device::describe;

pub const GIT_FOLDER_NAME: &str = ".git";
pub const HEAD_FILE_NAME: &str = "HEAD";
const CHECKOUT_FOLDER_NAME: &str = "app";

pub fn create_git_folder(
    parent: &Path,
    branch: &str,
) -> Result<PathBuf, String> {
    let folder = parent.join(CHECKOUT_FOLDER_NAME);
    let git_folder = folder.join(GIT_FOLDER_NAME);
    fs::create_dir_all(&git_folder).map_err(describe)?;
    let head = format!("ref: refs/heads/{branch}\n");
    fs::write(git_folder.join(HEAD_FILE_NAME), head).map_err(describe)?;
    Ok(folder)
}
