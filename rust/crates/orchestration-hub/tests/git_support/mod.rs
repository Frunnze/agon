use std::error::Error;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use orchestration_core::identifiers::TaskId;
use orchestration_core::workspace::{AgentAccess, Repository};
use orchestration_hub::clone_source::{ADDRESS_PLACEHOLDER, CloneSource};
use orchestration_hub::worktree_plan::{
    WorktreeLifetime, WorktreePlan, WorktreeRequest, plan_worktree,
};
use serde_json::json;
use tempfile::TempDir;

pub type TestResult<T> = Result<T, Box<dyn Error>>;

const ORIGINS_FOLDER_NAME: &str = "origins";
const ORIGIN_OWNER: &str = "local.test/acme";

const GIT_TEST_SETTINGS: [&str; 8] = [
    "-c",
    "user.name=Runner Test",
    "-c",
    "user.email=runner@example.com",
    "-c",
    "commit.gpgsign=false",
    "-c",
    "core.hooksPath=/dev/null",
];

#[derive(Debug)]
pub struct RunnerFolders {
    pub temporary: TempDir,
    pub cache_root: PathBuf,
    pub worktrees_root: PathBuf,
}

pub fn run_git(directory: &Path, arguments: &[&str]) -> TestResult<String> {
    let output = Command::new("git")
        .args(GIT_TEST_SETTINGS)
        .args(arguments)
        .current_dir(directory)
        .output()?;
    if !output.status.success() {
        let problem = String::from_utf8_lossy(&output.stderr).to_string();
        return Err(problem.into());
    }
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

pub fn commit_file(
    repository: &Path,
    name: &str,
    content: &str,
) -> TestResult<()> {
    fs::write(repository.join(name), content)?;
    run_git(repository, &["add", name])?;
    run_git(repository, &["commit", "--message", &format!("Add {name}")])?;
    Ok(())
}

pub fn prepare_runner_folders() -> TestResult<RunnerFolders> {
    let temporary = tempfile::tempdir()?;
    Ok(RunnerFolders {
        cache_root: temporary.path().join("cache"),
        worktrees_root: temporary.path().join("worktrees"),
        temporary,
    })
}

fn origins_root(folders: &RunnerFolders) -> PathBuf {
    folders.temporary.path().join(ORIGINS_FOLDER_NAME)
}

pub fn create_origin(
    folders: &RunnerFolders,
    name: &str,
) -> TestResult<PathBuf> {
    let address = format!("{ORIGIN_OWNER}/{name}");
    let origin = origins_root(folders).join(address);
    fs::create_dir_all(&origin)?;
    run_git(&origin, &["init", "--initial-branch=main"])?;
    commit_file(&origin, "README.md", "hello")?;
    Ok(origin)
}

pub fn numbered_task_id(number: u128) -> TestResult<TaskId> {
    let identifier = format!("{number:032x}");
    Ok(serde_json::from_value(json!(identifier))?)
}

pub fn plan_for(
    folders: &RunnerFolders,
    task_id: TaskId,
    title: &str,
    lifetime: WorktreeLifetime,
    origins: &[PathBuf],
) -> TestResult<WorktreePlan> {
    let origins_root = origins_root(folders);
    let template =
        format!("file://{}/{ADDRESS_PLACEHOLDER}", origins_root.display());
    let mut repositories = Vec::new();
    for origin in origins {
        let address = origin.strip_prefix(&origins_root)?;
        repositories.push(Repository {
            address: address.display().to_string(),
            default_branch: "main".to_string(),
            agent_access: AgentAccess::PushAfterApproval,
        });
    }
    let request = WorktreeRequest {
        task_id,
        task_title: title.to_string(),
        lifetime,
        repositories,
        cache_root: folders.cache_root.clone(),
        worktrees_root: folders.worktrees_root.clone(),
        clone_source: CloneSource::from_template(&template)?,
    };
    Ok(plan_worktree(&request)?)
}
