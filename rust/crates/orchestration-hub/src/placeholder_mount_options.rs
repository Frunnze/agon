use std::path::Path;

use crate::safe_paths::is_plain_absolute_path;
use crate::sandbox::{SandboxError, bind_mount, breaks_mount_syntax};
use crate::workspace_mounts::{
    CONTAINER_WORKSPACE_DIRECTORY, PlaceholderMount, WorkspaceMounts,
};

const READ_ONLY_OPTION: &str = "readonly";
const TARGET_SEPARATOR: &str = "/";

pub(crate) fn describe_placeholder_mounts(
    mounts: &WorkspaceMounts,
) -> Result<Vec<String>, SandboxError> {
    let mut descriptions = Vec::new();
    for placeholder_mount in &mounts.placeholder_mounts {
        let target =
            describe_covered_target(&mounts.task_folder, placeholder_mount)?;
        let source = placeholder_mount.placeholder.display().to_string();
        let read_only_mount =
            format!("{},{READ_ONLY_OPTION}", bind_mount(&source, &target));
        descriptions.push(read_only_mount);
    }
    Ok(descriptions)
}

fn describe_covered_target(
    task_folder: &Path,
    placeholder_mount: &PlaceholderMount,
) -> Result<String, SandboxError> {
    let covered_path = &placeholder_mount.covered_path;
    let unsafe_cover =
        || SandboxError::UnsafeCoveredPath(covered_path.clone());
    let placeholder = &placeholder_mount.placeholder;
    let is_mountable = is_plain_absolute_path(covered_path)
        && is_plain_absolute_path(placeholder)
        && !breaks_mount_syntax(covered_path)
        && !breaks_mount_syntax(placeholder);
    if !is_mountable {
        return Err(unsafe_cover());
    }

    let relative = covered_path
        .strip_prefix(task_folder)
        .map_err(|_outside| unsafe_cover())?;
    let mut target = CONTAINER_WORKSPACE_DIRECTORY.to_string();
    for component in relative.components() {
        let name = component.as_os_str().to_str().ok_or_else(unsafe_cover)?;
        target.push_str(TARGET_SEPARATOR);
        target.push_str(name);
    }
    if target == CONTAINER_WORKSPACE_DIRECTORY {
        return Err(unsafe_cover());
    }
    Ok(target)
}
