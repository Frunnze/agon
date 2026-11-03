use orchestration_core::device::Device;

use crate::live_link_messages::{FileAnswer, FileRequest};
use crate::node::{DeviceSession, Node};
use crate::node_error::NodeError;
use crate::peer_side::ask_runner_for_files;
#[cfg(feature = "runner")]
pub(super) use crate::runner_bridge::holds_own_copy;
#[cfg(feature = "runner")]
use crate::runner_bridge::read_own_copy;

pub(super) async fn ask_holder_for_files(
    node: &Node,
    session: &DeviceSession,
    holder: &Device,
    request: FileRequest,
) -> Result<FileAnswer, NodeError> {
    if holder.id == session.account.device.id {
        let cache_root = node.device_files().repository_cache_directory();
        return read_own_copy(session, &cache_root, request).await;
    }
    ask_runner_for_files(node.peer_side()?, holder, request).await
}

#[cfg(not(feature = "runner"))]
#[allow(clippy::unnecessary_wraps)]
pub(super) fn holds_own_copy(
    _cache_root: &std::path::Path,
    _address: &str,
) -> Result<bool, NodeError> {
    Ok(false)
}

#[cfg(not(feature = "runner"))]
#[allow(clippy::unused_async)]
async fn read_own_copy(
    _session: &DeviceSession,
    _cache_root: &std::path::Path,
    _request: FileRequest,
) -> Result<FileAnswer, NodeError> {
    Err(NodeError::RunnerUnavailable)
}
