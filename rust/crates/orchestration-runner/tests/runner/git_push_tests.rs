use orchestration_runner::branch_pusher::{BranchPusher, GitBranchPusher};
use orchestration_runner::git_command::GitError;
use orchestration_runner::unpushed_commits::list_unpushed_commit_subjects;
use proptest::collection::vec;
use proptest::prelude::*;
use tokio::runtime::Runtime;

use crate::git_support::{
    branch_subjects, clone_working_copy, commit_empty, create_bare_origin,
    run_git,
};
use crate::support::{TestResult, to_case_error};

const TASK_BRANCH: &str = "task/fix-the-build";

fn push_commits_to_bare_origin(
    subjects: &[String],
) -> TestResult<(Vec<String>, Vec<String>, Vec<String>)> {
    let runtime = Runtime::new()?;
    let folder = tempfile::tempdir()?;
    let origin = create_bare_origin(folder.path(), "app", &[])?;
    let working_copy =
        clone_working_copy(&origin, &folder.path().join("work/app"))?;
    run_git(&working_copy, &["switch", "--quiet", "-c", TASK_BRANCH])?;
    for subject in subjects {
        commit_empty(&working_copy, subject)?;
    }

    let before_push =
        runtime.block_on(list_unpushed_commit_subjects(&working_copy))?;
    runtime
        .block_on(GitBranchPusher.push_branch(&working_copy, TASK_BRANCH))?;
    let after_push =
        runtime.block_on(list_unpushed_commit_subjects(&working_copy))?;
    let mut pushed = branch_subjects(&origin, TASK_BRANCH)?;
    pushed.retain(|subject| subject != "Start");
    Ok((before_push, after_push, pushed))
}

#[tokio::test]
async fn reports_a_push_that_git_refuses() -> TestResult<()> {
    let folder = tempfile::tempdir()?;
    run_git(folder.path(), &["init", "--quiet"])?;
    commit_empty(folder.path(), "Local only")?;

    let pushed = GitBranchPusher
        .push_branch(folder.path(), TASK_BRANCH)
        .await;

    assert!(matches!(pushed, Err(GitError::Failed { .. })));
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(6))]

    #[test]
    fn test_push_branch_property_moves_every_unpushed_commit_to_origin(
        subjects in vec("[a-zA-Z0-9][a-zA-Z0-9 ,.:_-]{0,20}[a-zA-Z0-9]", 0..4),
    ) {
        let (before_push, after_push, pushed) =
            push_commits_to_bare_origin(&subjects).map_err(to_case_error)?;

        prop_assert_eq!(&before_push, &subjects);
        prop_assert!(after_push.is_empty());
        prop_assert_eq!(&pushed, &subjects);
    }

    #[test]
    fn test_list_unpushed_commit_subjects_property_lists_oldest_first(
        subjects in vec("[a-z]{1,10}", 1..4),
    ) {
        let (before_push, _after_push, _pushed) =
            push_commits_to_bare_origin(&subjects).map_err(to_case_error)?;

        prop_assert_eq!(before_push, subjects);
    }
}
