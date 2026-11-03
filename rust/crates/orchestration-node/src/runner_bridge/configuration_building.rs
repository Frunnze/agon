use std::collections::BTreeMap;
use std::path::Path;

use crate::device_files::REPOSITORY_CACHE_DIRECTORY_NAME;
use crate::node_error::NodeError;
use crate::runner_settings::{
    ContainerEngineChoice, RunnerSettings, SandboxSettings,
};
use orchestration_core::device::{RunnerLink, SandboxKind};
use orchestration_hub::clone_source::CloneSource;
use orchestration_hub::sandbox::{ContainerEngine, ContainerSettings};
use orchestration_runner::agent_sandbox::AgentSandbox;
use orchestration_runner::runner_configuration::{
    RunnerConfiguration, RunnerIntervals, WorktreeRoots,
    validate_configuration,
};

const WORKTREES_FOLDER_NAME: &str = "worktrees";
const RUNNER_LINK: RunnerLink = RunnerLink::Direct;

pub fn build_runner_configuration(
    settings: &RunnerSettings,
    offered_sandboxes: &[SandboxSettings],
    data_directory: &Path,
    process_environment: &BTreeMap<String, String>,
) -> Result<RunnerConfiguration, NodeError> {
    let agent_environment =
        pick_passed_environment(settings, process_environment)?;
    let mut sandboxes = Vec::new();
    for offered in offered_sandboxes {
        sandboxes.push(describe_sandbox(offered, agent_environment.clone()));
    }
    let worktree_roots = WorktreeRoots {
        cache_root: data_directory.join(REPOSITORY_CACHE_DIRECTORY_NAME),
        worktrees_root: data_directory.join(WORKTREES_FOLDER_NAME),
    };
    let configuration = RunnerConfiguration {
        labels: settings.labels.clone(),
        slot_capacity: settings.slot_capacity,
        link: RUNNER_LINK,
        sandboxes,
        worktree_roots,
        clone_source: describe_clone_source(settings)?,
        intervals: RunnerIntervals::standard(),
    };
    validate_configuration(&configuration).map_err(|problem| {
        NodeError::Startup(format!("invalid runner settings: {problem}"))
    })?;
    Ok(configuration)
}

fn describe_clone_source(
    settings: &RunnerSettings,
) -> Result<CloneSource, NodeError> {
    let Some(template) = &settings.clone_url_template else {
        return Ok(CloneSource::standard());
    };
    CloneSource::from_template(template).map_err(|problem| {
        NodeError::Startup(format!("invalid runner settings: {problem}"))
    })
}

fn pick_passed_environment(
    settings: &RunnerSettings,
    process_environment: &BTreeMap<String, String>,
) -> Result<BTreeMap<String, String>, NodeError> {
    let mut agent_environment = BTreeMap::new();
    for name in &settings.passed_environment {
        let Some(value) = process_environment.get(name) else {
            return Err(NodeError::Startup(format!(
                "invalid runner settings: passed_environment names \
                 {name}, which is not set for this runner"
            )));
        };
        agent_environment.insert(name.clone(), value.clone());
    }
    Ok(agent_environment)
}

fn describe_sandbox(
    sandbox: &SandboxSettings,
    agent_environment: BTreeMap<String, String>,
) -> AgentSandbox {
    match sandbox {
        SandboxSettings::LocalProcess => AgentSandbox {
            kind: SandboxKind::LocalProcess,
            container: unused_container(),
            allowed_hosts: Vec::new(),
            environment: agent_environment,
        },
        SandboxSettings::Container {
            engine,
            image,
            allowed_hosts,
        } => AgentSandbox {
            kind: SandboxKind::Container,
            container: ContainerSettings {
                engine: choose_engine(*engine),
                image: image.clone(),
            },
            allowed_hosts: allowed_hosts.clone(),
            environment: agent_environment,
        },
    }
}

fn unused_container() -> ContainerSettings {
    ContainerSettings {
        engine: ContainerEngine::Docker,
        image: String::new(),
    }
}

fn choose_engine(engine: ContainerEngineChoice) -> ContainerEngine {
    match engine {
        ContainerEngineChoice::Docker => ContainerEngine::Docker,
        ContainerEngineChoice::Podman => ContainerEngine::Podman,
    }
}
