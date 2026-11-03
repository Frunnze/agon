use orchestration_core::identifiers::DeviceId;
use orchestration_core::local_folders::normalize_folder_path;
use orchestration_core::repository_address::parse_repository_address;

use super::item_draft::RepositoryDraft;
use super::problem_sentences::describe_repository_problem;
use crate::commands::local_folder_checks::{
    check_local_folder, require_folder_on_this_device,
};

const FORM_DEFAULT_BRANCH: &str = "main";

pub(super) fn resolve_repository(
    device_id: &DeviceId,
    answered: &RepositoryDraft,
) -> Result<RepositoryDraft, String> {
    let address = answered.address.trim();
    if normalize_folder_path(address).is_ok() {
        return resolve_folder_path(device_id, address);
    }
    let answered_branch = answered.default_branch.trim();
    let default_branch = if answered_branch.is_empty() {
        FORM_DEFAULT_BRANCH
    } else {
        answered_branch
    };
    resolve_repository_address(device_id, address, default_branch)
}

fn resolve_folder_path(
    device_id: &DeviceId,
    path: &str,
) -> Result<RepositoryDraft, String> {
    let checked_folder = check_local_folder(device_id, path)
        .map_err(describe_repository_problem)?;
    Ok(RepositoryDraft {
        address: checked_folder.address,
        default_branch: checked_folder.default_branch,
    })
}

fn resolve_repository_address(
    device_id: &DeviceId,
    address: &str,
    default_branch: &str,
) -> Result<RepositoryDraft, String> {
    let canonical_address = parse_repository_address(address)
        .map_err(describe_repository_problem)?;
    require_folder_on_this_device(device_id, &canonical_address)
        .map_err(describe_repository_problem)?;
    Ok(RepositoryDraft {
        address: canonical_address,
        default_branch: default_branch.to_owned(),
    })
}
