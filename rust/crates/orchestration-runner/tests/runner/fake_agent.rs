use std::collections::BTreeMap;
use std::fs;
use std::path::PathBuf;
use std::time::Duration;

use orchestration_core::device::{RunnerLink, SandboxKind};
use orchestration_hub::clone_source::{ADDRESS_PLACEHOLDER, CloneSource};
use orchestration_hub::sandbox::{ContainerEngine, ContainerSettings};
use orchestration_runner::agent_sandbox::AgentSandbox;
use orchestration_runner::runner_configuration::{
    RunnerConfiguration, RunnerIntervals, WorktreeRoots,
};
use tempfile::TempDir;

use crate::git_support::origins_folder;
use crate::support::TestResult;

pub const FIXTURES: &str =
    concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures");
pub const RUNNER_LABEL: &str = "mac";
pub const ALLOWED_HOST: &str = "api.anthropic.com";
const RECORDS_VARIABLE: &str = "AGENT_RECORDS";
const PATH_VARIABLE: &str = "PATH";
const CALLS_FILE: &str = "calls.txt";
const WORKING_FOLDERS_FILE: &str = "folders.txt";
const TEST_HEARTBEAT_INTERVAL: Duration = Duration::from_millis(50);
const TEST_CLAIM_INTERVAL: Duration = Duration::from_millis(10);
const TEST_CANCELLATION_CHECK_INTERVAL: Duration = Duration::from_millis(20);

#[derive(Debug)]
pub struct AgentFolders {
    pub temporary: TempDir,
    pub records: PathBuf,
    pub cache_root: PathBuf,
    pub worktrees_root: PathBuf,
}

pub fn prepare_agent_folders() -> TestResult<AgentFolders> {
    let temporary = tempfile::tempdir()?;
    let records = temporary.path().join("records");
    fs::create_dir_all(&records)?;
    Ok(AgentFolders {
        records,
        cache_root: temporary.path().join("cache"),
        worktrees_root: temporary.path().join("worktrees"),
        temporary,
    })
}

pub fn test_container() -> ContainerSettings {
    ContainerSettings {
        engine: ContainerEngine::Docker,
        image: "agents/runner".to_string(),
    }
}

pub fn local_configuration(
    folders: &AgentFolders,
    slot_capacity: u32,
) -> TestResult<RunnerConfiguration> {
    let system_path = std::env::var(PATH_VARIABLE)?;
    let fake_path = format!("{FIXTURES}/bin:{system_path}");
    let records = folders.records.display().to_string();
    let environment = BTreeMap::from([
        (PATH_VARIABLE.to_string(), fake_path),
        (RECORDS_VARIABLE.to_string(), records),
    ]);

    Ok(RunnerConfiguration {
        labels: vec![RUNNER_LABEL.to_string()],
        slot_capacity,
        link: RunnerLink::Direct,
        sandbox: AgentSandbox {
            kind: SandboxKind::LocalProcess,
            container: test_container(),
            allowed_hosts: vec![ALLOWED_HOST.to_string()],
            environment,
        },
        worktree_roots: WorktreeRoots {
            cache_root: folders.cache_root.clone(),
            worktrees_root: folders.worktrees_root.clone(),
        },
        clone_source: local_clone_source(folders)?,
        intervals: RunnerIntervals {
            heartbeat: TEST_HEARTBEAT_INTERVAL,
            claim: TEST_CLAIM_INTERVAL,
            cancellation_check: TEST_CANCELLATION_CHECK_INTERVAL,
        },
    })
}

fn local_clone_source(folders: &AgentFolders) -> TestResult<CloneSource> {
    let origins = origins_folder(folders.temporary.path());
    let template =
        format!("file://{}/{ADDRESS_PLACEHOLDER}.git", origins.display());
    Ok(CloneSource::from_template(&template)?)
}

pub fn read_calls(folders: &AgentFolders) -> TestResult<Vec<String>> {
    let calls_path = folders.records.join(CALLS_FILE);
    if !calls_path.exists() {
        return Ok(Vec::new());
    }
    let calls = fs::read_to_string(calls_path)?;
    Ok(calls.lines().map(ToString::to_string).collect())
}

pub fn read_working_folders(
    folders: &AgentFolders,
) -> TestResult<Vec<PathBuf>> {
    let working_folders_path = folders.records.join(WORKING_FOLDERS_FILE);
    if !working_folders_path.exists() {
        return Ok(Vec::new());
    }
    let working_folders = fs::read_to_string(working_folders_path)?;
    Ok(working_folders.lines().map(PathBuf::from).collect())
}

pub fn has_agent_records(folders: &AgentFolders) -> TestResult<bool> {
    let mut records = fs::read_dir(&folders.records)?;
    Ok(records.next().is_some())
}

pub fn read_prompt(folders: &AgentFolders, name: &str) -> TestResult<String> {
    let prompt_path = folders.records.join(format!("prompt-{name}.txt"));
    Ok(fs::read_to_string(prompt_path)?)
}
