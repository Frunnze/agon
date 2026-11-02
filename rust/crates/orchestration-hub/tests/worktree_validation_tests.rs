mod worktree_support;

use std::path::PathBuf;

use orchestration_core::repository_address::parse_repository_address;
use orchestration_hub::worktree_plan::{
    WorktreeProblem, WorktreeRequest, plan_worktree,
};
use proptest::prelude::*;
use worktree_support::{
    any_canonical_address, any_hostile_title, any_lifetime, any_task_id,
    plan_or_fail, repository_at, request_for,
};

#[derive(Clone, Copy, Debug)]
enum RunnerRoot {
    Cache,
    Worktrees,
}

fn any_unsafe_root() -> impl Strategy<Value = PathBuf> {
    prop_oneof![
        "[a-z]{1,8}(/[a-z]{1,8}){0,2}".prop_map(PathBuf::from),
        "/[a-z]{1,8}/\\.\\.(/[a-z]{1,8}){0,2}".prop_map(PathBuf::from),
        Just(PathBuf::from("/")),
    ]
}

fn any_runner_root() -> impl Strategy<Value = RunnerRoot> {
    prop_oneof![Just(RunnerRoot::Cache), Just(RunnerRoot::Worktrees)]
}

fn any_invalid_default_branch() -> impl Strategy<Value = String> {
    prop_oneof![
        Just(String::new()),
        "-[a-z]{1,6}",
        "[a-z]{1,4}[ ~^:?*\\[\\\\][a-z]{0,4}",
        "[a-z]{1,4}\\.\\.[a-z]{1,4}",
    ]
}

fn replace_root(
    request: WorktreeRequest,
    root: RunnerRoot,
    path: PathBuf,
) -> WorktreeRequest {
    match root {
        RunnerRoot::Cache => WorktreeRequest {
            cache_root: path,
            ..request
        },
        RunnerRoot::Worktrees => WorktreeRequest {
            worktrees_root: path,
            ..request
        },
    }
}

proptest! {
    #[test]
    fn test_plan_worktree_property_folders_are_named_after_repositories(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        owner in "[a-z]{1,8}",
        name in "[a-z]([a-z0-9]|-[a-z0-9]){0,10}",
    ) {
        let address = format!("github.com/{owner}/{name}");
        let repositories = vec![repository_at(&address)];
        let request = request_for(task_id, &title, lifetime, repositories);

        let plan = plan_or_fail(&request)?;

        let worktree = plan.repositories[0].worktree.clone();
        prop_assert_eq!(worktree, plan.task_folder.join(&name));
    }

    #[test]
    fn test_plan_worktree_property_unsafe_roots_are_rejected(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        unsafe_root in any_unsafe_root(),
        root in any_runner_root(),
    ) {
        let request = request_for(task_id, &title, lifetime, vec![]);
        let request = replace_root(request, root, unsafe_root.clone());

        let planned = plan_worktree(&request);

        let expected = WorktreeProblem::UnsafeRoot(unsafe_root);
        prop_assert_eq!(planned, Err(expected));
    }

    #[test]
    fn test_plan_worktree_property_invalid_default_branch_is_rejected(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        default_branch in any_invalid_default_branch(),
    ) {
        let mut repository = repository_at("github.com/team/app");
        repository.default_branch = default_branch.clone();
        let request = request_for(task_id, &title, lifetime, vec![repository]);

        let planned = plan_worktree(&request);

        let expected = WorktreeProblem::InvalidDefaultBranch(default_branch);
        prop_assert_eq!(planned, Err(expected));
    }

    #[test]
    fn test_plan_worktree_property_unusable_address_is_rejected(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in prop_oneof![
            "[ \t]{0,4}",
            "[a-z]{1,6}[\\x00-\\x1f\\x7f][a-z]{0,6}",
            "https://github\\.com/[a-z]{1,8}/[a-z]{1,8}\\.git",
            "git@github\\.com:[a-z]{1,8}/[a-z]{1,8}\\.git",
            "(\\.\\./){1,4}[a-z]{0,6}",
            "/[a-z/.]{1,20}",
        ],
    ) {
        let repositories = vec![repository_at(&address)];
        let request = request_for(task_id, &title, lifetime, repositories);

        let planned = plan_worktree(&request);

        let expected = WorktreeProblem::InvalidRepositoryAddress(address);
        prop_assert_eq!(planned, Err(expected));
    }

    #[test]
    fn test_plan_worktree_property_accepts_exactly_canonical_addresses(
        task_id in any_task_id(),
        lifetime in any_lifetime(),
        address in prop_oneof![
            any_canonical_address(),
            "[a-z./:@-]{1,30}",
        ],
    ) {
        let repositories = vec![repository_at(&address)];
        let request = request_for(task_id, "a", lifetime, repositories);

        let planned = plan_worktree(&request);

        let is_canonical =
            parse_repository_address(&address).as_deref() == Ok(&address);
        prop_assert_eq!(planned.is_ok(), is_canonical);
    }

    #[test]
    fn test_plan_worktree_property_duplicate_repository_names_are_rejected(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        name in "[a-z]{1,10}",
        first_owner in "[a-z]{1,8}",
        second_owner in "[a-z]{1,8}",
    ) {
        let first_address = format!("github.com/{first_owner}/{name}");
        let second_address = format!("gitlab.com/{second_owner}/{name}");
        let repositories = vec![
            repository_at(&first_address),
            repository_at(&second_address),
        ];
        let request = request_for(task_id, &title, lifetime, repositories);

        let planned = plan_worktree(&request);

        let expected = WorktreeProblem::DuplicateRepositoryName(name);
        prop_assert_eq!(planned, Err(expected));
    }
}
