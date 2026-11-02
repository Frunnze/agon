use orchestration_core::identifiers::DeviceId;
use orchestration_core::local_folders::parse_local_address;

use super::draft_kind::DraftKind;
use super::item_draft::{ItemDraft, ProjectDraft, RepositoryDraft};
use crate::commands::local_folder_checks::require_folder_on_this_device;
use crate::node_error::NodeError;

pub(crate) fn require_project_folders(
    kind: DraftKind,
    chosen_folders: &[RepositoryDraft],
) -> Result<(), NodeError> {
    if kind != DraftKind::Project && !chosen_folders.is_empty() {
        return Err(NodeError::FoldersOutsideProject(kind.name()));
    }
    Ok(())
}

pub(crate) fn require_chosen_folders(
    device_id: &DeviceId,
    kind: DraftKind,
    chosen_folders: &[RepositoryDraft],
) -> Result<(), NodeError> {
    require_project_folders(kind, chosen_folders)?;
    for chosen in chosen_folders {
        parse_local_address(&chosen.address)?;
        require_folder_on_this_device(device_id, &chosen.address)?;
    }
    Ok(())
}

pub(super) fn list_folder_paths(
    chosen_folders: &[RepositoryDraft],
) -> Result<Vec<String>, NodeError> {
    let mut paths = Vec::new();
    for chosen in chosen_folders {
        let folder = parse_local_address(&chosen.address)?;
        paths.push(folder.path);
    }
    Ok(paths)
}

#[must_use]
pub fn add_chosen_folders(
    drafted: ItemDraft,
    chosen_folders: &[RepositoryDraft],
) -> ItemDraft {
    let ItemDraft::Project(project) = drafted else {
        return drafted;
    };
    let mut repositories = project.repositories;
    repositories.extend_from_slice(chosen_folders);
    ItemDraft::Project(ProjectDraft {
        repositories,
        ..project
    })
}
