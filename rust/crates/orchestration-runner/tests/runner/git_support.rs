use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use orchestration_core::workspace::{AgentAccess, Repository};

use crate::support::TestResult;

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
const DEFAULT_BRANCH: &str = "main";
const ORIGINS_FOLDER_NAME: &str = "origins";
const ORIGIN_OWNER: &str = "local.test/acme";

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

pub fn create_bare_origin(
    root: &Path,
    name: &str,
    files: &[(&str, &str)],
) -> TestResult<PathBuf> {
    let seed = root.join("seeds").join(name);
    fs::create_dir_all(&seed)?;
    run_git(&seed, &["init", "--quiet", "--initial-branch=main"])?;
    fs::write(seed.join("README.md"), "hello")?;
    for (file_name, content) in files {
        fs::write(seed.join(file_name), content)?;
    }
    run_git(&seed, &["add", "--all"])?;
    run_git(&seed, &["commit", "--quiet", "--message", "Start"])?;

    let origins = origins_folder(root);
    let origin = origins.join(format!("{ORIGIN_OWNER}/{name}.git"));
    let origin_parent = origin.parent().ok_or("the origin has no parent")?;
    fs::create_dir_all(origin_parent)?;
    let seed_text = seed.display().to_string();
    let origin_text = origin.display().to_string();
    run_git(
        &origins,
        &["clone", "--quiet", "--bare", &seed_text, &origin_text],
    )?;
    Ok(origin)
}

pub fn origins_folder(root: &Path) -> PathBuf {
    root.join(ORIGINS_FOLDER_NAME)
}

pub fn repository_at(origin: &Path, agent_access: AgentAccess) -> Repository {
    let name = origin.file_stem().unwrap_or_default().to_string_lossy();
    Repository {
        address: format!("{ORIGIN_OWNER}/{name}"),
        default_branch: DEFAULT_BRANCH.to_string(),
        agent_access,
    }
}

pub fn clone_working_copy(
    origin: &Path,
    destination: &Path,
) -> TestResult<PathBuf> {
    let parent = destination.parent().ok_or("no parent folder")?;
    fs::create_dir_all(parent)?;
    let origin_text = origin.display().to_string();
    let destination_text = destination.display().to_string();
    run_git(
        parent,
        &["clone", "--quiet", &origin_text, &destination_text],
    )?;
    Ok(destination.to_path_buf())
}

pub fn commit_empty(directory: &Path, subject: &str) -> TestResult<()> {
    run_git(
        directory,
        &["commit", "--quiet", "--allow-empty", "--message", subject],
    )?;
    Ok(())
}

pub fn branch_subjects(
    origin: &Path,
    branch: &str,
) -> TestResult<Vec<String>> {
    let reference = format!("refs/heads/{branch}");
    let subjects =
        run_git(origin, &["log", "--reverse", "--format=%s", &reference])?;
    Ok(subjects.lines().map(ToString::to_string).collect())
}
