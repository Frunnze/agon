use std::fs;
use std::io::ErrorKind;
use std::path::Path;

use orchestration_core::identifiers::DeviceId;
use orchestration_core::local_folders::{
    normalize_folder_path, validate_new_folder_name,
};

use super::local_folder_checks::{
    CheckedFolder, check_local_folder, require_folder,
};
use crate::node_error::NodeError;

pub(crate) fn create_local_folder(
    device_id: &DeviceId,
    parent: &str,
    name: &str,
) -> Result<CheckedFolder, NodeError> {
    validate_new_folder_name(name)?;
    let parent_path = normalize_folder_path(parent)?;
    require_folder(&parent_path)?;

    let folder = Path::new(&parent_path).join(name);
    let folder_path = folder.display().to_string();
    fs::create_dir(&folder).map_err(|error| {
        if error.kind() == ErrorKind::AlreadyExists {
            return NodeError::FolderExists(folder_path.clone());
        }
        NodeError::Storage(error)
    })?;

    check_local_folder(device_id, &folder_path)
}
