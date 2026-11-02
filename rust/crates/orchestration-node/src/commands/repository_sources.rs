use orchestration_core::device::{Device, Runner};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::workspace::Project;
use serde::Serialize;

use super::file_holders::ask_holder_for_files;
use crate::live_link_messages::{
    FileAnswer, FileRequest, RepositoryReference,
};
use crate::node::{DeviceSession, Node};
use crate::node_error::NodeError;
use crate::views::{RepositoryHolder, find_repository_holders};

const UNEXPECTED_ANSWER: &str = "the runner answered another question";

pub(super) struct SourceSearch<'search> {
    pub(super) node: &'search Node,
    pub(super) session: &'search DeviceSession,
    pub(super) runners: &'search [Runner],
    pub(super) devices: &'search [Device],
}

#[derive(Debug, Serialize)]
pub(super) struct SourceRunner {
    device_id: DeviceId,
    name: String,
}

#[derive(Debug, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub(super) enum RepositorySourceView {
    Available {
        runner: SourceRunner,
        branches: Vec<String>,
        task_branches: Vec<String>,
    },
    Unavailable {
        holders: Vec<RepositoryHolder>,
    },
}

pub(super) fn require_project_repository(
    projects: &[Project],
    repository: &RepositoryReference,
) -> Result<(), NodeError> {
    let project = projects
        .iter()
        .find(|project| project.id == repository.project_id)
        .ok_or_else(|| NodeError::NotFound {
            kind: "project",
            identifier: repository.project_id.0.to_string(),
        })?;
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

pub(super) async fn open_repository_source(
    search: &SourceSearch<'_>,
    repository: &RepositoryReference,
) -> Result<RepositorySourceView, NodeError> {
    let devices = search.devices;
    let holders =
        find_repository_holders(search.runners, devices, &repository.address);
    let mut last_problem = None;
    for holder in holders.iter().filter(|holder| holder.online) {
        let runner = find_runner_device(devices, &holder.device_id)?;
        let request = FileRequest::ListBranches {
            repository: repository.clone(),
        };
        let asking =
            ask_holder_for_files(search.node, search.session, runner, request);
        let answer = match asking.await {
            Ok(answer) => answer,
            Err(problem) => {
                last_problem = Some(problem);
                continue;
            }
        };
        let FileAnswer::Branches { branches } = answer else {
            return Err(unexpected_answer());
        };
        return Ok(RepositorySourceView::Available {
            runner: SourceRunner {
                device_id: holder.device_id.clone(),
                name: holder.name.clone(),
            },
            branches: branches.branches,
            task_branches: branches.task_branches,
        });
    }
    match last_problem {
        Some(problem) => Err(problem),
        None => Ok(RepositorySourceView::Unavailable { holders }),
    }
}

pub(super) fn find_runner_device<'devices>(
    devices: &'devices [Device],
    runner_id: &DeviceId,
) -> Result<&'devices Device, NodeError> {
    devices
        .iter()
        .find(|device| &device.id == runner_id && !device.revoked)
        .ok_or_else(|| NodeError::NotFound {
            kind: "runner",
            identifier: runner_id.0.clone(),
        })
}

pub(super) fn unexpected_answer() -> NodeError {
    NodeError::MalformedLinkMessage(UNEXPECTED_ANSWER.to_owned())
}
