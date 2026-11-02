use orchestration_api::work::RunEvent;
use orchestration_core::identifiers::{ProjectId, RunId};
use orchestration_core::repository_files::{
    RepositoryBranches, RepositoryEntry, RepositoryFile,
};
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};

use crate::node_error::NodeError;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ClientMessage {
    Watch { run_id: RunId },
    Chat { text: String },
    Browse { request: FileRequest },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RepositoryReference {
    pub project_id: ProjectId,
    pub address: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum FileRequest {
    ListBranches {
        repository: RepositoryReference,
    },
    ListFolder {
        repository: RepositoryReference,
        branch: String,
        folder: String,
    },
    ReadFile {
        repository: RepositoryReference,
        branch: String,
        path: String,
    },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum RunnerMessage {
    Accepted,
    Refused { reason: String },
    Events { events: Vec<RunEvent> },
    Answered { answer: FileAnswer },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum FileAnswer {
    Branches { branches: RepositoryBranches },
    Folder { entries: Vec<RepositoryEntry> },
    File { file: RepositoryFile },
}

impl FileRequest {
    #[must_use]
    pub fn repository(&self) -> &RepositoryReference {
        match self {
            Self::ListBranches { repository }
            | Self::ListFolder { repository, .. }
            | Self::ReadFile { repository, .. } => repository,
        }
    }
}

pub fn encode_link_message<Message: Serialize>(
    message: &Message,
) -> Result<Vec<u8>, NodeError> {
    Ok(serde_json::to_vec(message)?)
}

pub fn decode_link_message<Message: DeserializeOwned>(
    frame: &[u8],
) -> Result<Message, NodeError> {
    serde_json::from_slice(frame)
        .map_err(|error| NodeError::MalformedLinkMessage(error.to_string()))
}
