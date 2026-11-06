use std::path::Path;

use crate::node_error::NodeError;

const GIT_PROGRAM: &str = "git";
const GIT_FOLDER_NAME: &str = ".git";
const FIRST_BRANCH_REFERENCE: &str = "refs/heads/main";
const FIRST_COMMIT_SUBJECT_START: &str = "Start";
const CONFIGURATION_OPTION: &str = "-c";
const FALLBACK_IDENTITY: [(&str, &str); 2] = [
    ("user.name", "Agon"),
    ("user.email", "agon@agents-orchestration.invalid"),
];

pub(crate) fn start_git_when_missing(
    folder: &Path,
) -> Result<bool, NodeError> {
    if !folder.join(GIT_FOLDER_NAME).is_dir() {
        run_git(folder, &["init", "--quiet"])?;
    }
    if has_commits(folder)? {
        return Ok(false);
    }
    make_first_commit(folder)?;
    Ok(true)
}

fn has_commits(folder: &Path) -> Result<bool, NodeError> {
    let head_check =
        start_git(folder, &["rev-parse", "--verify", "--quiet", "HEAD"])?;
    Ok(head_check.has_succeeded)
}

fn make_first_commit(folder: &Path) -> Result<(), NodeError> {
    run_git(folder, &["symbolic-ref", "HEAD", FIRST_BRANCH_REFERENCE])?;
    run_git(folder, &["add", "--all"])?;

    let folder_name = folder.file_name().unwrap_or(folder.as_os_str());
    let subject = format!(
        "{FIRST_COMMIT_SUBJECT_START} {}",
        folder_name.to_string_lossy()
    );
    let mut arguments = list_missing_identity_settings(folder)?;
    arguments.extend([
        "commit".to_owned(),
        "--quiet".to_owned(),
        "--allow-empty".to_owned(),
        "--message".to_owned(),
        subject,
    ]);
    run_git(folder, &arguments)
}

fn list_missing_identity_settings(
    folder: &Path,
) -> Result<Vec<String>, NodeError> {
    let mut settings = Vec::new();
    for (key, fallback_value) in FALLBACK_IDENTITY {
        let configured = start_git(folder, &["config", "--get", key])?;
        if !configured.has_succeeded {
            settings.push(CONFIGURATION_OPTION.to_owned());
            settings.push(format!("{key}={fallback_value}"));
        }
    }
    Ok(settings)
}

struct GitAnswer {
    has_succeeded: bool,
    errors: String,
}

fn run_git<Argument: AsRef<str>>(
    folder: &Path,
    arguments: &[Argument],
) -> Result<(), NodeError> {
    let answer = start_git(folder, arguments)?;
    if answer.has_succeeded {
        return Ok(());
    }
    Err(describe_git_problem(folder, answer.errors.trim()))
}

#[cfg(unix)]
fn start_git<Argument: AsRef<str>>(
    folder: &Path,
    arguments: &[Argument],
) -> Result<GitAnswer, NodeError> {
    let owned_arguments: Vec<String> = arguments
        .iter()
        .map(|argument| argument.as_ref().to_owned())
        .collect();
    let outcome = crate::reaper_safe_program::run_program(
        GIT_PROGRAM,
        &owned_arguments,
        folder,
    )
    .map_err(|error| describe_git_problem(folder, &error.to_string()))?;
    Ok(GitAnswer {
        has_succeeded: outcome.has_succeeded(),
        errors: outcome.errors,
    })
}

#[cfg(not(unix))]
fn start_git<Argument: AsRef<str>>(
    folder: &Path,
    arguments: &[Argument],
) -> Result<GitAnswer, NodeError> {
    let output = std::process::Command::new(GIT_PROGRAM)
        .args(arguments.iter().map(AsRef::as_ref))
        .current_dir(folder)
        .output()
        .map_err(|error| describe_git_problem(folder, &error.to_string()))?;
    Ok(GitAnswer {
        has_succeeded: output.status.success(),
        errors: String::from_utf8_lossy(&output.stderr).into_owned(),
    })
}

fn describe_git_problem(folder: &Path, problem: &str) -> NodeError {
    NodeError::GitNotStarted {
        folder: folder.display().to_string(),
        problem: problem.to_owned(),
    }
}
