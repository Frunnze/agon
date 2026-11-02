use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use super::test_device::describe;

pub const LOCAL_REPOSITORY_ADDRESS: &str = "local.test/acme/app";
const GIT_PROGRAM: &str = "git";
const SEED_FOLDER_NAME: &str = "seed";
const GIT_TEST_SETTINGS: [&str; 8] = [
    "-c",
    "user.name=Node Test",
    "-c",
    "user.email=node@example.com",
    "-c",
    "commit.gpgsign=false",
    "-c",
    "core.hooksPath=/dev/null",
];

pub fn run_git(
    directory: &Path,
    arguments: &[&str],
) -> Result<String, String> {
    let output = Command::new(GIT_PROGRAM)
        .args(GIT_TEST_SETTINGS)
        .args(arguments)
        .current_dir(directory)
        .output()
        .map_err(describe)?;
    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).into_owned());
    }
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_owned())
}

pub fn create_local_origin(root: &Path) -> Result<PathBuf, String> {
    let seed = root.join(SEED_FOLDER_NAME);
    fs::create_dir_all(&seed).map_err(describe)?;
    run_git(&seed, &["init", "--quiet", "--initial-branch=main"])?;
    fs::write(seed.join("README.md"), "hello").map_err(describe)?;
    run_git(&seed, &["add", "--all"])?;
    run_git(&seed, &["commit", "--quiet", "--message", "Start"])?;

    let origin = root.join(LOCAL_REPOSITORY_ADDRESS);
    let origin_parent = origin.parent().ok_or("the origin has no parent")?;
    fs::create_dir_all(origin_parent).map_err(describe)?;
    let seed_text = seed.display().to_string();
    let origin_text = origin.display().to_string();
    run_git(
        root,
        &["clone", "--quiet", "--bare", &seed_text, &origin_text],
    )?;
    Ok(origin)
}

pub fn read_branch_subject(
    origin: &Path,
    branch: &str,
) -> Result<String, String> {
    run_git(origin, &["log", "-1", "--format=%s", branch])
}
