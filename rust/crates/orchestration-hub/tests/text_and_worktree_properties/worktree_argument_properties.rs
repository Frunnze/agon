use std::collections::BTreeSet;
use std::path::PathBuf;

use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::slugs::slugify;
use orchestration_hub::worktree_plan::{
    RepositoryWorktreePlan, WorktreePlan, WorktreeRequest,
};
use proptest::prelude::*;

use crate::worktree_support::{
    any_canonical_address, any_hostile_title, any_lifetime, any_task_id,
    plan_or_fail, repository_at, request_for,
};

const TERMINAL_PROMPT_VARIABLE: &str = "GIT_TERMINAL_PROMPT";
const CEILING_VARIABLE: &str = "GIT_CEILING_DIRECTORIES";

fn any_hostile_root() -> impl Strategy<Value = PathBuf> {
    proptest::collection::vec("[a-zA-Z0-9 '\"$`;&|*?é中-]{1,10}", 1..4)
        .prop_map(|folders| PathBuf::from(format!("/{}", folders.join("/"))))
        .prop_filter("names are never dots", |root| {
            root.to_str().is_some_and(|text| {
                !text.contains("/./") && !text.contains("/../")
            })
        })
}

fn any_addresses() -> impl Strategy<Value = BTreeSet<String>> {
    proptest::collection::btree_set(any_canonical_address(), 1..4).prop_filter(
        "every repository has its own name",
        |addresses| {
            let mut names = BTreeSet::new();
            for address in addresses {
                let last_segment = address.rsplit('/').next();
                let name = slugify(last_segment.unwrap_or_default());
                if name.is_empty() || !names.insert(name) {
                    return false;
                }
            }
            true
        },
    )
}

fn every_command(
    planned: &RepositoryWorktreePlan,
) -> [&CommandSpecification; 5] {
    [
        &planned.clone_command,
        &planned.fetch_command,
        &planned.add_worktree_command,
        &planned.remove_worktree_command,
        &planned.delete_branch_command,
    ]
}

fn plan_hostile_roots(
    request: WorktreeRequest,
    cache_root: PathBuf,
    worktrees_root: PathBuf,
) -> Result<WorktreePlan, TestCaseError> {
    let hostile = WorktreeRequest {
        cache_root,
        worktrees_root,
        ..request
    };
    plan_or_fail(&hostile)
}

proptest! {
    #[test]
    fn test_remove_worktree_command_property_force_removes_the_worktree(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
    ) {
        let request = request_for(
            task_id,
            &title,
            lifetime,
            vec![repository_at(&address)],
        );
        let plan = plan_or_fail(&request)?;
        let planned = &plan.repositories[0];

        let expected = vec![
            "worktree".to_owned(),
            "remove".to_owned(),
            "--force".to_owned(),
            planned.worktree.display().to_string(),
        ];
        prop_assert_eq!(&planned.remove_worktree_command.arguments, &expected);
    }

    #[test]
    fn test_remove_worktree_command_property_hostile_paths_stay_one_argument(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
        cache_root in any_hostile_root(),
        worktrees_root in any_hostile_root(),
    ) {
        let repositories = vec![repository_at(&address)];
        let request = request_for(task_id, &title, lifetime, repositories);
        let plan =
            plan_hostile_roots(request, cache_root, worktrees_root.clone())?;
        let planned = &plan.repositories[0];

        let arguments = &planned.remove_worktree_command.arguments;
        prop_assert_eq!(arguments.len(), 4);
        prop_assert_eq!(
            PathBuf::from(&arguments[3]),
            planned.worktree.clone()
        );
        prop_assert!(planned.worktree.starts_with(&worktrees_root));
    }

    #[test]
    fn test_remove_worktree_command_property_runs_in_the_cached_clone(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        addresses in any_addresses(),
    ) {
        let repositories = addresses
            .iter()
            .map(|address| repository_at(address))
            .collect();
        let request = request_for(task_id, &title, lifetime, repositories);
        let plan = plan_or_fail(&request)?;

        for planned in &plan.repositories {
            let directory =
                planned.remove_worktree_command.working_directory.as_ref();
            prop_assert_eq!(directory, Some(&planned.cached_clone));
        }
    }

    #[test]
    fn test_delete_branch_command_property_force_deletes_the_task_branch(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        addresses in any_addresses(),
    ) {
        let repositories = addresses
            .iter()
            .map(|address| repository_at(address))
            .collect();
        let request = request_for(task_id, &title, lifetime, repositories);
        let plan = plan_or_fail(&request)?;

        let expected =
            vec!["branch".to_owned(), "-D".to_owned(), plan.branch.clone()];
        for planned in &plan.repositories {
            prop_assert_eq!(
                &planned.delete_branch_command.arguments,
                &expected
            );
        }
    }

    #[test]
    fn test_delete_branch_command_property_branch_never_reads_as_an_option(
        task_id in any_task_id(),
        title in prop_oneof![any_hostile_title(), Just("-D --all".to_owned())],
        lifetime in any_lifetime(),
        address in any_canonical_address(),
    ) {
        let request = request_for(
            task_id,
            &title,
            lifetime,
            vec![repository_at(&address)],
        );
        let plan = plan_or_fail(&request)?;

        let arguments = &plan.repositories[0].delete_branch_command.arguments;
        prop_assert_eq!(arguments.len(), 3);
        prop_assert!(!arguments[2].starts_with('-'));
    }

    #[test]
    fn test_delete_branch_command_property_each_clone_deletes_its_own(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        addresses in any_addresses(),
    ) {
        let repositories = addresses
            .iter()
            .map(|address| repository_at(address))
            .collect();
        let request = request_for(task_id, &title, lifetime, repositories);
        let plan = plan_or_fail(&request)?;

        let directories: BTreeSet<_> = plan
            .repositories
            .iter()
            .map(|planned| {
                planned.delete_branch_command.working_directory.clone()
            })
            .collect();
        prop_assert_eq!(directories.len(), addresses.len());
        for planned in &plan.repositories {
            let directory =
                planned.delete_branch_command.working_directory.as_ref();
            prop_assert_eq!(directory, Some(&planned.cached_clone));
        }
    }

    #[test]
    fn test_git_command_property_every_command_runs_git_without_prompts(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
    ) {
        let request = request_for(
            task_id,
            &title,
            lifetime,
            vec![repository_at(&address)],
        );
        let planned = plan_or_fail(&request)?.repositories[0].clone();

        for command in every_command(&planned) {
            prop_assert_eq!(&command.program, "git");
            let prompt = command.environment.get(TERMINAL_PROMPT_VARIABLE);
            prop_assert_eq!(prompt.map(String::as_str), Some("0"));
        }
    }

    #[test]
    fn test_git_command_property_git_never_searches_above_the_clone(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
        cache_root in any_hostile_root(),
        worktrees_root in any_hostile_root(),
    ) {
        let repositories = vec![repository_at(&address)];
        let request = request_for(task_id, &title, lifetime, repositories);
        let plan = plan_hostile_roots(request, cache_root, worktrees_root)?;

        for command in every_command(&plan.repositories[0]) {
            let ceiling =
                command.environment.get(CEILING_VARIABLE).map(PathBuf::from);
            let expected = command
                .working_directory
                .as_ref()
                .and_then(|directory| directory.parent())
                .map(std::path::Path::to_path_buf);
            prop_assert_eq!(ceiling, expected);
        }
    }

    #[test]
    fn test_git_command_property_arguments_are_never_quoted(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
        cache_root in any_hostile_root(),
        worktrees_root in any_hostile_root(),
    ) {
        let repositories = vec![repository_at(&address)];
        let request = request_for(task_id, &title, lifetime, repositories);
        let plan = plan_hostile_roots(request, cache_root, worktrees_root)?;
        let planned = &plan.repositories[0];

        let clone_destination =
            planned.clone_command.arguments.last().map(PathBuf::from);
        let worktree_argument =
            PathBuf::from(&planned.add_worktree_command.arguments[4]);
        prop_assert_eq!(clone_destination, Some(planned.cached_clone.clone()));
        prop_assert_eq!(worktree_argument, planned.worktree.clone());
    }
}
