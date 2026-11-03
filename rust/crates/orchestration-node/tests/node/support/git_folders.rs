use std::fs;
use std::path::{Path, PathBuf};

use super::git_origin::run_git;
use super::test_device::describe;

pub const GIT_FOLDER_NAME: &str = ".git";
const CHECKOUT_FOLDER_NAME: &str = "app";
const FIRST_FILE_NAME: &str = "README.md";
const FIRST_FILE_TEXT: &str = "hello";

pub fn create_git_folder(
    parent: &Path,
    branch: &str,
) -> Result<PathBuf, String> {
    create_named_git_folder(parent, CHECKOUT_FOLDER_NAME, branch)
}

pub fn create_named_git_folder(
    parent: &Path,
    name: &str,
    branch: &str,
) -> Result<PathBuf, String> {
    let folder = parent.join(name);
    fs::create_dir_all(&folder).map_err(describe)?;
    let initial_branch = format!("--initial-branch={branch}");
    run_git(&folder, &["init", "--quiet", &initial_branch])?;
    fs::write(folder.join(FIRST_FILE_NAME), FIRST_FILE_TEXT)
        .map_err(describe)?;
    run_git(&folder, &["add", "--all"])?;
    run_git(&folder, &["commit", "--quiet", "--message", "Start"])?;
    Ok(folder)
}
