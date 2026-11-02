use orchestration_core::identifiers::{DeviceId, ProjectId};
use orchestration_core::repository_files::RepositoryEntry;
use orchestration_core::repository_paths::{
    normalize_file_path, normalize_folder_path,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::file_holders::ask_holder_for_files;
use super::repository_sources::{
    SourceSearch, find_runner_device, open_repository_source,
    require_project_repository, unexpected_answer,
};
use crate::command_reply::encode_reply;
use crate::live_link_messages::{
    FileAnswer, FileRequest, RepositoryReference,
};
use crate::node::Node;
use crate::node_error::NodeError;

pub(super) const FILE_COMMAND_NAMES: [&str; 3] = [
    "list_repository_branches",
    "list_repository_files",
    "read_repository_file",
];

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum FileCommand {
    ListRepositoryBranches {
        project_id: ProjectId,
        repository_address: String,
    },
    ListRepositoryFiles {
        project_id: ProjectId,
        repository_address: String,
        runner_id: DeviceId,
        branch: String,
        folder: String,
    },
    ReadRepositoryFile {
        project_id: ProjectId,
        repository_address: String,
        runner_id: DeviceId,
        branch: String,
        path: String,
    },
}

#[derive(Debug, Serialize)]
struct FolderView {
    entries: Vec<RepositoryEntry>,
}

pub(super) async fn handle_file_command(
    node: &Node,
    command: FileCommand,
) -> Result<Value, NodeError> {
    match command {
        FileCommand::ListRepositoryBranches {
            project_id,
            repository_address,
        } => {
            let repository = RepositoryReference {
                project_id,
                address: repository_address,
            };
            list_repository_branches(node, &repository).await
        }
        FileCommand::ListRepositoryFiles {
            project_id,
            repository_address,
            runner_id,
            branch,
            folder,
        } => {
            let request = FileRequest::ListFolder {
                repository: RepositoryReference {
                    project_id,
                    address: repository_address,
                },
                branch,
                folder: normalize_folder_path(&folder)?,
            };
            let answer = ask_runner(node, &runner_id, request).await?;
            let FileAnswer::Folder { entries } = answer else {
                return Err(unexpected_answer());
            };
            encode_reply(&FolderView { entries })
        }
        FileCommand::ReadRepositoryFile {
            project_id,
            repository_address,
            runner_id,
            branch,
            path,
        } => {
            let request = FileRequest::ReadFile {
                repository: RepositoryReference {
                    project_id,
                    address: repository_address,
                },
                branch,
                path: normalize_file_path(&path)?,
            };
            let answer = ask_runner(node, &runner_id, request).await?;
            let FileAnswer::File { file } = answer else {
                return Err(unexpected_answer());
            };
            encode_reply(&file)
        }
    }
}

async fn list_repository_branches(
    node: &Node,
    repository: &RepositoryReference,
) -> Result<Value, NodeError> {
    let session = node.open_session()?;
    let client = session.client();
    let projects = client.list_projects().await?;
    require_project_repository(&projects, repository)?;
    let runners = client.list_runners().await?;
    let devices = client.list_devices().await?;
    let search = SourceSearch {
        node,
        session: &session,
        runners: &runners,
        devices: &devices,
    };
    let source = open_repository_source(&search, repository).await?;
    encode_reply(&source)
}

async fn ask_runner(
    node: &Node,
    runner_id: &DeviceId,
    request: FileRequest,
) -> Result<FileAnswer, NodeError> {
    let session = node.open_session()?;
    let devices = session.client().list_devices().await?;
    let runner = find_runner_device(&devices, runner_id)?;
    ask_holder_for_files(node, &session, runner, request).await
}
