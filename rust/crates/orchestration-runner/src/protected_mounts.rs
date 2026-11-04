use orchestration_core::device::SandboxKind;
use orchestration_core::protected_files::ProtectedFiles;
use orchestration_hub::protected_file_covers::cover_protected_files;
use orchestration_hub::workspace_mounts::WorkspaceMounts;
use tokio::task::spawn_blocking;

use crate::run_error::RunError;

pub(crate) async fn hide_protected_files(
    sandbox_kind: SandboxKind,
    mounts: &WorkspaceMounts,
    protected_files: &ProtectedFiles,
) -> Result<WorkspaceMounts, RunError> {
    if sandbox_kind != SandboxKind::Container {
        return Ok(mounts.clone());
    }

    let visible_mounts = mounts.clone();
    let protected = protected_files.clone();
    let covering = spawn_blocking(move || {
        cover_protected_files(&visible_mounts, &protected)
    });
    covering.await?.map_err(RunError::ProtectedFilesNotHidden)
}
