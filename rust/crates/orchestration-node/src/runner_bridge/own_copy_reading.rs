use std::path::Path;

use super::file_host::read_cached_clone;
use super::file_readers::check_reader_access;
use crate::live_link_messages::{FileAnswer, FileRequest};
use crate::node::DeviceSession;
use crate::node_error::NodeError;

pub(crate) async fn read_own_copy(
    session: &DeviceSession,
    cache_root: &Path,
    request: FileRequest,
) -> Result<FileAnswer, NodeError> {
    let client = session.client();
    let devices = client.list_devices().await?;
    let projects = client.list_projects().await?;
    let this_device_id = &session.account.device.id;
    let this_device = devices
        .iter()
        .find(|device| &device.id == this_device_id)
        .ok_or(NodeError::UntrustedFileReader)?;
    check_reader_access(this_device, &projects, request.repository())?;
    read_cached_clone(cache_root, request).await
}
