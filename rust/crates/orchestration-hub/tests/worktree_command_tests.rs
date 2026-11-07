mod worktree_support;

use std::collections::BTreeMap;
use std::path::Path;
use std::process::Command;

use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::worktree_plan::{RepositoryWorktreePlan, WorktreePlan};
use proptest::prelude::*;
use worktree_support::{
    CACHE_ROOT, WORKTREES_ROOT, any_canonical_address, any_hostile_title,
    any_lifetime, any_task_id, plan_or_fail, repository_at, request_for,
};

fn any_default_branch() -> impl Strategy<Value = String> {
    "[a-z]{1,8}(/[a-z0-9]{1,8}){0,2}"
}

fn git_command(
    working_directory: Option<&Path>,
    arguments: &[&str],
) -> CommandSpecification {
    let mut environment =
        BTreeMap::from([("GIT_TERMINAL_PROMPT".to_string(), "0".to_string())]);
    if let Some(enclosing_folder) = working_directory.and_then(Path::parent) {
        environment.insert(
            "GIT_CEILING_DIRECTORIES".to_string(),
            enclosing_folder.display().to_string(),
        );
    }
    CommandSpecification {
        program: "git".to_string(),
        arguments: arguments.iter().map(ToString::to_string).collect(),
        environment,
        working_directory: working_directory.map(Path::to_path_buf),
    }
}

fn displayed(path: &Path) -> String {
    path.display().to_string()
}

fn first_repository(
    plan: &WorktreePlan,
) -> Result<RepositoryWorktreePlan, TestCaseError> {
    plan.repositories
        .first()
        .cloned()
        .ok_or_else(|| TestCaseError::fail("the plan has no repository"))
}

fn git_accepts_branch(name: &str) -> Result<bool, std::io::Error> {
    let outside_any_repository = tempfile::tempdir()?;
    let status = Command::new("git")
        .args(["check-ref-format", "--branch", name])
        .current_dir(outside_any_repository.path())
        .output()?
        .status;
    Ok(status.success())
}

proptest! {
    #[test]
    fn test_plan_worktree_property_git_commands_are_exact(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
        default_branch in any_default_branch(),
    ) {
        let mut repository = repository_at(&address);
        repository.default_branch = default_branch.clone();
        let request = request_for(task_id, &title, lifetime, vec![repository]);

        let plan = plan_or_fail(&request)?;
        let planned = first_repository(&plan)?;

        let cached_clone = planned.cached_clone.as_path();
        prop_assert!(cached_clone.starts_with(CACHE_ROOT));
        prop_assert!(planned.worktree.starts_with(WORKTREES_ROOT));
        let worktree = displayed(&planned.worktree);
        let origin_branch = format!("origin/{default_branch}");
        let clone_url = format!("https://{address}.git");
        let clone_arguments = [
            "clone",
            "--no-checkout",
            "--",
            &clone_url,
            &displayed(cached_clone),
        ];
        let add_arguments = [
            "worktree",
            "add",
            "-b",
            &plan.branch,
            &worktree,
            &origin_branch,
        ];
        prop_assert_eq!(
            &planned.clone_command,
            &git_command(None, &clone_arguments),
        );
        prop_assert_eq!(
            &planned.fetch_command,
            &git_command(Some(cached_clone), &["fetch", "--prune", "origin"]),
        );
        prop_assert_eq!(
            &planned.add_worktree_command,
            &git_command(Some(cached_clone), &add_arguments),
        );
        prop_assert_eq!(
            &planned.remove_worktree_command,
            &git_command(
                Some(cached_clone),
                &["worktree", "remove", "--force", &worktree],
            ),
        );
        prop_assert_eq!(
            &planned.delete_branch_command,
            &git_command(Some(cached_clone), &["branch", "-D", &plan.branch]),
        );
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(32))]

    #[test]
    fn test_plan_worktree_property_branch_names_pass_git_check(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
    ) {
        let request = request_for(task_id, &title, lifetime, vec![]);
        let plan = plan_or_fail(&request)?;

        let accepted = git_accepts_branch(&plan.branch)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert!(accepted);
    }
}
