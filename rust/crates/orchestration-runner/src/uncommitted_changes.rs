use std::path::Path;

use orchestration_core::agent_kind_label::describe_agent_kind;
use orchestration_core::workflow::AgentKind;

use crate::agents_file::AGENTS_FILE_NAME;
use crate::git_command::{GitError, run_git};

pub const COMMITTER_NAME: &str = "Agon Runner";
pub const COMMITTER_EMAIL: &str = "runner@agents-orchestration.invalid";

const CONFIGURATION_OPTION: &str = "-c";
const SIGNING_DISABLED_SETTING: &str = "commit.gpgsign=false";
const STEP_SUBJECT_SEPARATOR: &str = "; ";

#[must_use]
pub fn compose_change_commit_subject(
    step_name: &str,
    agent: AgentKind,
) -> String {
    let agent_name = describe_agent_kind(agent);
    format!("{step_name}: changes from {agent_name}")
}

#[must_use]
pub fn combine_change_commit_subjects(step_subjects: &[String]) -> String {
    step_subjects.join(STEP_SUBJECT_SEPARATOR)
}

pub async fn commit_uncommitted_changes(
    worktree: &Path,
    subject: &str,
) -> Result<(), GitError> {
    run_git(worktree, &["add", "--all"]).await?;
    let unstage_agents_file = ["reset", "--quiet", "--", AGENTS_FILE_NAME];
    run_git(worktree, &unstage_agents_file).await?;

    let staged_files =
        run_git(worktree, &["diff", "--cached", "--name-only"]).await?;
    if staged_files.is_empty() {
        return Ok(());
    }

    let name_setting = format!("user.name={COMMITTER_NAME}");
    let email_setting = format!("user.email={COMMITTER_EMAIL}");
    let arguments = [
        CONFIGURATION_OPTION,
        name_setting.as_str(),
        CONFIGURATION_OPTION,
        email_setting.as_str(),
        CONFIGURATION_OPTION,
        SIGNING_DISABLED_SETTING,
        "commit",
        "--quiet",
        "--no-verify",
        "--message",
        subject,
    ];
    run_git(worktree, &arguments).await?;
    Ok(())
}
