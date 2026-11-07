use std::collections::BTreeSet;
use std::path::Path;

use orchestration_hub::slugs::slugify;
use orchestration_hub::worktree_plan::WorktreeLifetime;
use proptest::prelude::*;

use crate::worktree_support::{
    any_canonical_address, any_hostile_title, any_lifetime, any_task_id,
    plan_or_fail, repository_at, request_for,
};

fn folder_name_of(path: &Path) -> String {
    let name = path.file_name().unwrap_or_default();
    name.to_string_lossy().into_owned()
}

fn name_of_address(address: &str) -> String {
    slugify(address.rsplit('/').next().unwrap_or_default())
}

proptest! {
    #[test]
    fn test_plan_repository_property_repositories_keep_their_order(
        task_id in any_task_id(),
        addresses in proptest::collection::vec(any_canonical_address(), 1..4),
    ) {
        let names: BTreeSet<String> =
            addresses.iter().map(|address| name_of_address(address)).collect();
        prop_assume!(names.len() == addresses.len() && !names.contains(""));
        let repositories = addresses
            .iter()
            .map(|address| repository_at(address))
            .collect();

        let plan = plan_or_fail(&request_for(
            task_id,
            "Fix",
            WorktreeLifetime::PerTask,
            repositories,
        ))?;

        let planned_names: Vec<String> = plan
            .repositories
            .iter()
            .map(|planned| folder_name_of(&planned.worktree))
            .collect();
        let expected_names: Vec<String> =
            addresses.iter().map(|address| name_of_address(address)).collect();
        prop_assert_eq!(planned_names, expected_names);
    }

    #[test]
    fn test_plan_repository_property_commands_share_the_cached_clone(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
    ) {
        let plan = plan_or_fail(&request_for(
            task_id,
            &title,
            lifetime,
            vec![repository_at(&address)],
        ))?;
        let planned = &plan.repositories[0];

        let working_commands = [
            &planned.fetch_command,
            &planned.add_worktree_command,
            &planned.remove_worktree_command,
            &planned.delete_branch_command,
        ];
        for command in working_commands {
            prop_assert_eq!(
                command.working_directory.as_ref(),
                Some(&planned.cached_clone)
            );
        }
        let destination = planned
            .clone_command
            .arguments
            .last()
            .cloned()
            .unwrap_or_default();
        prop_assert_eq!(
            destination,
            planned.cached_clone.display().to_string()
        );
    }

    #[test]
    fn test_plan_repository_property_default_branch_reaches_only_the_start(
        task_id in any_task_id(),
        address in any_canonical_address(),
        default_branch in "zz[a-z]{4,8}",
    ) {
        let mut repository = repository_at(&address);
        repository.default_branch = default_branch.clone();

        let plan = plan_or_fail(&request_for(
            task_id,
            "Fix",
            WorktreeLifetime::PerTask,
            vec![repository],
        ))?;

        let planned = &plan.repositories[0];
        let starting_point = format!("origin/{default_branch}");
        prop_assert_eq!(
            planned.add_worktree_command.arguments.last(),
            Some(&starting_point)
        );
        let other_commands = [
            &planned.clone_command,
            &planned.fetch_command,
            &planned.remove_worktree_command,
            &planned.delete_branch_command,
        ];
        for command in other_commands {
            let mentions = command
                .arguments
                .iter()
                .any(|argument| argument.contains(&default_branch));
            prop_assert!(!mentions, "{:?}", command.arguments);
        }
    }
}
