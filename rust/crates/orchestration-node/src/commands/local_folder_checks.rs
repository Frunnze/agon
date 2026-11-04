use std::fs;
use std::path::Path;

use orchestration_core::identifiers::DeviceId;
use orchestration_core::local_folders::{
    LocalFolder, is_local_address, normalize_folder_path, parse_local_address,
    render_local_address,
};
use serde::Serialize;

use super::folder_git_start::start_git_when_missing;
use crate::node_error::NodeError;

const GIT_FOLDER_NAME: &str = ".git";
const HEAD_FILE_NAME: &str = "HEAD";
const BRANCH_REFERENCE_PREFIX: &str = "ref: refs/heads/";

#[derive(Debug, Serialize)]
pub(crate) struct CheckedFolder {
    pub(crate) address: String,
    pub(crate) default_branch: String,
    pub(crate) has_started_git: bool,
}

pub(crate) fn check_local_folder(
    device_id: &DeviceId,
    path: &str,
) -> Result<CheckedFolder, NodeError> {
    let folder = LocalFolder {
        device_id: device_id.clone(),
        path: normalize_folder_path(path)?,
    };
    require_folder(&folder.path)?;
    let has_started_git = start_git_when_missing(Path::new(&folder.path))?;
    let default_branch = read_checked_out_branch(&folder.path)?;
    Ok(CheckedFolder {
        address: render_local_address(&folder)?,
        default_branch,
        has_started_git,
    })
}

pub(crate) fn require_folder_on_this_device(
    device_id: &DeviceId,
    address: &str,
) -> Result<(), NodeError> {
    if !is_local_address(address) {
        return Ok(());
    }
    let folder = parse_local_address(address)?;
    if folder.device_id != *device_id {
        return Err(NodeError::FolderOnAnotherDevice(folder.path));
    }
    require_git_checkout(&folder.path)
}

pub(super) fn require_folder(path: &str) -> Result<(), NodeError> {
    if !Path::new(path).is_dir() {
        return Err(NodeError::FolderMissing(path.to_owned()));
    }
    Ok(())
}

fn require_git_checkout(path: &str) -> Result<(), NodeError> {
    require_folder(path)?;
    if !Path::new(path).join(GIT_FOLDER_NAME).is_dir() {
        return Err(NodeError::NotGitRepository(path.to_owned()));
    }
    Ok(())
}

fn read_checked_out_branch(path: &str) -> Result<String, NodeError> {
    let head_file = Path::new(path).join(GIT_FOLDER_NAME).join(HEAD_FILE_NAME);
    let head = fs::read_to_string(head_file)
        .map_err(|_| NodeError::NotGitRepository(path.to_owned()))?;
    let branch = head.trim().strip_prefix(BRANCH_REFERENCE_PREFIX);
    match branch {
        Some(branch) if !branch.is_empty() => Ok(branch.to_owned()),
        _ => Err(NodeError::NoCheckedOutBranch(path.to_owned())),
    }
}
