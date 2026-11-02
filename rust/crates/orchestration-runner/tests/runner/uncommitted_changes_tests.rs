use std::collections::BTreeSet;
use std::fs;
use std::path::Path;

use orchestration_core::agent_kind_label::describe_agent_kind;
use orchestration_core::workflow::AgentKind;
use orchestration_runner::agents_file::AGENTS_FILE_NAME;
use orchestration_runner::git_command::GitError;
use orchestration_runner::uncommitted_changes::{
    COMMITTER_EMAIL, COMMITTER_NAME, commit_uncommitted_changes,
    compose_change_commit_subject,
};
use proptest::prelude::*;
use tokio::runtime::Runtime;

use crate::assignments::any_agent_kind;
use crate::git_support::run_git;
use crate::leftover_changes::{
    CREATED_CONTENT, CREATED_FILE_NAMES, PROJECT_AGENTS_NOTES,
    ProjectAgentsFile, check_out_repository, commit_count, commit_subjects,
    committed_agents_file, files_in_last_commit, leave_changes,
    leftover_changes, remaining_changes,
};
use crate::support::{TestResult, to_case_error};

const SUBJECT: &str = "build: changes from Codex";
const IDENTITY_FORMAT: &str = "--format=%an|%ae|%cn|%ce";

fn commit_with_runtime(
    worktree: &Path,
    subject: &str,
) -> TestResult<Result<(), GitError>> {
    let runtime = Runtime::new()?;
    Ok(runtime.block_on(commit_uncommitted_changes(worktree, subject)))
}

#[test]
fn composes_the_subject_from_the_step_and_the_agent() {
    let subject = compose_change_commit_subject("build", AgentKind::GeminiCli);

    assert_eq!(subject, "build: changes from Gemini CLI");
}

#[test]
fn commits_under_the_agon_runner_name() {
    assert_eq!(COMMITTER_NAME, "Agon Runner");
}

#[tokio::test]
async fn reports_a_folder_that_is_not_a_repository() -> TestResult<()> {
    let folder = tempfile::tempdir()?;
    fs::write(folder.path().join("notes.txt"), CREATED_CONTENT)?;

    let committed = commit_uncommitted_changes(folder.path(), SUBJECT).await;

    assert!(matches!(committed, Err(GitError::Failed { .. })));
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(8))]

    #[test]
    fn test_compose_change_commit_subject_property_names_step_then_agent(
        step_name in "[a-z0-9-]{1,40}",
        agent in any_agent_kind(),
    ) {
        let subject = compose_change_commit_subject(&step_name, agent);

        let step_prefix = format!("{step_name}: ");
        let agent_ending = format!(" {}", describe_agent_kind(agent));
        prop_assert!(subject.starts_with(&step_prefix));
        prop_assert!(subject.ends_with(&agent_ending));
        prop_assert!(!subject.contains('\n'));
    }

    #[test]
    fn test_commit_uncommitted_changes_property_commits_all_but_agents_file(
        changes in leftover_changes(0..3),
    ) {
        let repository = check_out_repository(changes.project_agents_file)
            .map_err(to_case_error)?;
        let worktree = &repository.worktree;
        let changed_files =
            leave_changes(worktree, &changes).map_err(to_case_error)?;
        let subjects_before =
            commit_subjects(worktree).map_err(to_case_error)?;

        commit_with_runtime(worktree, SUBJECT)
            .map_err(to_case_error)?
            .map_err(to_case_error)?;

        let subjects_after = commit_subjects(worktree).map_err(to_case_error)?;
        let remaining = remaining_changes(worktree).map_err(to_case_error)?;
        let only_agents_file = BTreeSet::from([AGENTS_FILE_NAME.to_string()]);
        prop_assert!(remaining.is_subset(&only_agents_file));
        if changed_files.is_empty() {
            prop_assert_eq!(subjects_after, subjects_before);
            return Ok(());
        }
        let mut expected_subjects = vec![SUBJECT.to_string()];
        expected_subjects.extend(subjects_before);
        let committed_files =
            files_in_last_commit(worktree).map_err(to_case_error)?;
        prop_assert_eq!(subjects_after, expected_subjects);
        prop_assert_eq!(committed_files, changed_files);
    }

    #[test]
    fn test_commit_uncommitted_changes_property_keeps_project_agents_file(
        changes in leftover_changes(0..3),
    ) {
        let repository = check_out_repository(changes.project_agents_file)
            .map_err(to_case_error)?;
        let worktree = &repository.worktree;
        leave_changes(worktree, &changes).map_err(to_case_error)?;

        commit_with_runtime(worktree, SUBJECT)
            .map_err(to_case_error)?
            .map_err(to_case_error)?;

        let committed =
            committed_agents_file(worktree).map_err(to_case_error)?;
        let expected = match changes.project_agents_file {
            ProjectAgentsFile::Tracked => {
                Some(PROJECT_AGENTS_NOTES.to_string())
            }
            ProjectAgentsFile::Absent => None,
        };
        prop_assert_eq!(committed, expected);
    }

    #[test]
    fn test_commit_uncommitted_changes_property_commits_as_the_runner(
        changes in leftover_changes(1..3),
    ) {
        let repository = check_out_repository(changes.project_agents_file)
            .map_err(to_case_error)?;
        let worktree = &repository.worktree;
        leave_changes(worktree, &changes).map_err(to_case_error)?;

        commit_with_runtime(worktree, SUBJECT)
            .map_err(to_case_error)?
            .map_err(to_case_error)?;

        let identities = run_git(worktree, &["log", "-1", IDENTITY_FORMAT])
            .map_err(to_case_error)?;
        let runner = format!("{COMMITTER_NAME}|{COMMITTER_EMAIL}");
        prop_assert_eq!(identities, format!("{runner}|{runner}"));
    }

    #[test]
    fn test_commit_uncommitted_changes_property_commits_once_or_not_at_all(
        subject in any::<String>(),
        created_file in CREATED_FILE_NAMES,
    ) {
        let repository = check_out_repository(ProjectAgentsFile::Absent)
            .map_err(to_case_error)?;
        let worktree = &repository.worktree;
        fs::write(worktree.join(&created_file), CREATED_CONTENT)
            .map_err(to_case_error)?;
        let commits_before = commit_count(worktree).map_err(to_case_error)?;

        let committed = commit_with_runtime(worktree, &subject)
            .map_err(to_case_error)?;

        let commits_after = commit_count(worktree).map_err(to_case_error)?;
        let added_commits = commits_after - commits_before;
        prop_assert_eq!(added_commits, u64::from(committed.is_ok()));
    }
}
