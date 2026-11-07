use std::fs::{self, Permissions};
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

use crate::hosted_files::hosted_server_directory;
use crate::support::test_device::{TestDevice, describe};

pub const READ_ONLY_FOLDER_MODE: u32 = 0o500;
pub const OPEN_FOLDER_MODE: u32 = 0o700;
const LOCKED_FOLDER_NAME: &str = "locked";

pub fn set_folder_mode(folder: &Path, mode: u32) -> Result<(), String> {
    fs::set_permissions(folder, Permissions::from_mode(mode)).map_err(describe)
}

pub fn lock_server_folder(
    device: &TestDevice,
    file_name: &str,
) -> Result<PathBuf, String> {
    let locked_folder =
        hosted_server_directory(device).join(LOCKED_FOLDER_NAME);
    fs::create_dir_all(&locked_folder).map_err(describe)?;
    fs::write(locked_folder.join(file_name), file_name).map_err(describe)?;
    set_folder_mode(&locked_folder, READ_ONLY_FOLDER_MODE)?;
    Ok(locked_folder)
}
