use orchestration_core::device::Device;
use orchestration_core::peer_address::ENDPOINT_PUBLIC_KEY_LENGTH;
use orchestration_core::workspace::Project;

use crate::device_roles::can_decide_approvals;
use crate::live_link_messages::RepositoryReference;
use crate::node_error::NodeError;
use crate::peer_side::trusted_peer_address;

pub fn check_file_reader(
    devices: &[Device],
    projects: &[Project],
    reader_key: &[u8; ENDPOINT_PUBLIC_KEY_LENGTH],
    repository: &RepositoryReference,
) -> Result<(), NodeError> {
    let reader = find_device_with_peer_key(devices, reader_key)
        .ok_or(NodeError::UntrustedFileReader)?;
    check_reader_access(reader, projects, repository)
}

pub fn check_reader_access(
    reader: &Device,
    projects: &[Project],
    repository: &RepositoryReference,
) -> Result<(), NodeError> {
    let project = projects
        .iter()
        .find(|project| project.id == repository.project_id)
        .ok_or(NodeError::UntrustedFileReader)?;
    let is_trusted_client = !reader.revoked
        && can_decide_approvals(reader.role)
        && reader.workspaces.contains(&project.workspace_id);
    if !is_trusted_client {
        return Err(NodeError::UntrustedFileReader);
    }

    let holds_repository = project
        .repositories
        .iter()
        .any(|listed| listed.address == repository.address);
    if !holds_repository {
        let address = repository.address.clone();
        return Err(NodeError::RepositoryOutsideProject(address));
    }
    Ok(())
}

pub(crate) fn find_device_with_peer_key<'devices>(
    devices: &'devices [Device],
    endpoint_key: &[u8; ENDPOINT_PUBLIC_KEY_LENGTH],
) -> Option<&'devices Device> {
    devices.iter().find(|device| {
        trusted_peer_address(device)
            .is_ok_and(|address| &address.endpoint_public_key == endpoint_key)
    })
}
