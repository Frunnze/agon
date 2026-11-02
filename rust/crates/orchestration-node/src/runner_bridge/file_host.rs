use std::path::Path;

use orchestration_core::peer_address::ENDPOINT_PUBLIC_KEY_LENGTH;
use orchestration_hub::cached_clones::cached_clone_folder;
use orchestration_hub::repository_reading::{
    RepositoryReadError, RepositoryReader,
};

use super::node_runner_server::NodeRunnerServer;
use crate::live_link_messages::{FileAnswer, FileRequest};
use crate::node_error::NodeError;

pub(crate) async fn answer_file_request(
    server: &NodeRunnerServer,
    cache_root: &Path,
    reader_key: &[u8; ENDPOINT_PUBLIC_KEY_LENGTH],
    request: FileRequest,
) -> Result<FileAnswer, NodeError> {
    let repository = request.repository();
    server.authorize_file_reader(repository, reader_key).await?;
    read_cached_clone(cache_root, request).await
}

pub(crate) async fn read_cached_clone(
    cache_root: &Path,
    request: FileRequest,
) -> Result<FileAnswer, NodeError> {
    let address = &request.repository().address;
    let cached_clone = cached_clone_folder(cache_root, address);
    let reading = tokio::task::spawn_blocking(move || {
        read_repository(&cached_clone, request)
    });
    reading
        .await
        .map_err(|problem| NodeError::RepositoryRead(problem.to_string()))?
}

fn read_repository(
    cached_clone: &Path,
    request: FileRequest,
) -> Result<FileAnswer, NodeError> {
    let reader = RepositoryReader::open(cached_clone)?;
    let answer = match request {
        FileRequest::ListBranches { .. } => FileAnswer::Branches {
            branches: reader.list_branches()?,
        },
        FileRequest::ListFolder { branch, folder, .. } => FileAnswer::Folder {
            entries: reader.list_folder(&branch, &folder)?,
        },
        FileRequest::ReadFile { branch, path, .. } => FileAnswer::File {
            file: reader.read_file(&branch, &path)?,
        },
    };
    Ok(answer)
}

impl From<RepositoryReadError> for NodeError {
    fn from(problem: RepositoryReadError) -> Self {
        Self::RepositoryRead(problem.to_string())
    }
}
