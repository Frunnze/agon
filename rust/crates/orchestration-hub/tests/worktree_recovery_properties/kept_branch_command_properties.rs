use std::path::Path;

use orchestration_core::identifiers::TaskId;
use orchestration_core::workspace::Repository;
use orchestration_hub::worktree_plan::{WorktreeLifetime, WorktreePlan};
use proptest::prelude::*;

use crate::worktree_folders::{CaseResult, REPOSITORY_NAMES};
use crate::worktree_support::{
    any_canonical_address, any_hostile_title, any_lifetime, any_task_id,
    plan_or_fail, repository_at, request_for,
};

const BRANCH_MOVING_OPTIONS: [&str; 5] =
    ["-b", "-B", "--force", "-f", "--detach"];
const REMOTE_START_PREFIX: &str = "origin/";
const ADDRESS_OWNER: &str = "host.test/acme";

fn displayed(path: &Path) -> String {
    path.display().to_string()
}

fn any_option_like_title() -> impl Strategy<Value = String> {
    prop_oneof![
        any_hostile_title(),
        Just("--force".to_owned()),
        Just("-b".to_owned()),
        Just("-B main".to_owned()),
    ]
}

fn plan_single(
    task_id: TaskId,
    address: &str,
    default_branch: &str,
) -> CaseResult<WorktreePlan> {
    let repository = Repository {
        default_branch: default_branch.to_owned(),
        ..repository_at(address)
    };
    let lifetime = WorktreeLifetime::PerTask;
    let request = request_for(task_id, "Fix", lifetime, vec![repository]);
    plan_or_fail(&request)
}

proptest! {
    #[test]
    fn test_add_kept_branch_worktree_command_property_checks_out_the_branch(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
    ) {
        let repositories = vec![repository_at(&address)];
        let request = request_for(task_id, &title, lifetime, repositories);
        let plan = plan_or_fail(&request)?;

        let planned = &plan.repositories[0];
        let command = &planned.add_kept_branch_worktree_command;

        let expected = vec![
            "worktree".to_owned(),
            "add".to_owned(),
            displayed(&planned.worktree),
            plan.branch.clone(),
        ];
        prop_assert_eq!(&command.arguments, &expected);
        prop_assert_eq!(
            command.working_directory.as_ref(),
            Some(&planned.cached_clone)
        );
    }

    #[test]
    fn test_add_kept_branch_worktree_command_property_no_option_lookalikes(
        task_id in any_task_id(),
        title in any_option_like_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
    ) {
        let repositories = vec![repository_at(&address)];
        let request = request_for(task_id, &title, lifetime, repositories);

        let plan = plan_or_fail(&request)?;

        let command = &plan.repositories[0].add_kept_branch_worktree_command;
        for argument in &command.arguments[2..] {
            prop_assert!(!argument.starts_with('-'), "{}", argument);
        }
    }

    #[test]
    fn test_add_kept_branch_worktree_command_property_never_moves_a_branch(
        task_id in any_task_id(),
        title in any_option_like_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
    ) {
        let repositories = vec![repository_at(&address)];
        let request = request_for(task_id, &title, lifetime, repositories);

        let plan = plan_or_fail(&request)?;

        let command = &plan.repositories[0].add_kept_branch_worktree_command;
        for argument in &command.arguments {
            let is_moving_option =
                BRANCH_MOVING_OPTIONS.contains(&argument.as_str());
            prop_assert!(!is_moving_option, "{:?}", command.arguments);
            let is_remote_start = argument.starts_with(REMOTE_START_PREFIX);
            prop_assert!(!is_remote_start, "{:?}", command.arguments);
        }
        let new_branch_command = &plan.repositories[0].add_worktree_command;
        prop_assert_eq!(
            &command.environment,
            &new_branch_command.environment
        );
    }

    #[test]
    fn test_plan_repository_property_both_add_commands_share_the_place(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
    ) {
        let repositories = vec![repository_at(&address)];
        let request = request_for(task_id, &title, lifetime, repositories);

        let plan = plan_or_fail(&request)?;

        let planned = &plan.repositories[0];
        let kept = &planned.add_kept_branch_worktree_command;
        let new = &planned.add_worktree_command;
        prop_assert_eq!(&kept.program, &new.program);
        prop_assert_eq!(&kept.working_directory, &new.working_directory);
        let worktree = displayed(&planned.worktree);
        prop_assert!(kept.arguments.contains(&worktree));
        prop_assert!(new.arguments.contains(&worktree));
        prop_assert!(kept.arguments.contains(&plan.branch));
        prop_assert!(new.arguments.contains(&plan.branch));
    }

    #[test]
    fn test_plan_repository_property_kept_command_ignores_default_branch(
        task_id in any_task_id(),
        address in any_canonical_address(),
        (first_default, second_default) in (
            "[a-z]{1,8}(/[a-z0-9_]{1,8}){0,2}",
            "[a-z]{1,8}(/[a-z0-9_]{1,8}){0,2}",
        ),
    ) {
        let first = plan_single(task_id, &address, &first_default)?;
        let second = plan_single(task_id, &address, &second_default)?;

        prop_assert_eq!(
            &first.repositories[0].add_kept_branch_worktree_command,
            &second.repositories[0].add_kept_branch_worktree_command
        );
        let first_start = first.repositories[0]
            .add_worktree_command
            .arguments
            .last()
            .cloned();
        prop_assert_eq!(
            first_start,
            Some(format!("{REMOTE_START_PREFIX}{first_default}"))
        );
    }

    #[test]
    fn test_plan_repository_property_each_repository_gets_its_kept_command(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        repository_count in 1..=REPOSITORY_NAMES.len(),
    ) {
        let mut repositories = Vec::new();
        for name in REPOSITORY_NAMES.iter().take(repository_count) {
            let address = format!("{ADDRESS_OWNER}/{name}");
            repositories.push(repository_at(&address));
        }
        let request = request_for(task_id, &title, lifetime, repositories);

        let plan = plan_or_fail(&request)?;

        prop_assert_eq!(plan.repositories.len(), repository_count);
        for planned in &plan.repositories {
            let command = &planned.add_kept_branch_worktree_command;
            prop_assert_eq!(
                command.working_directory.as_ref(),
                Some(&planned.cached_clone)
            );
            let worktree = displayed(&planned.worktree);
            prop_assert_eq!(&command.arguments[2], &worktree);
            prop_assert_eq!(&command.arguments[3], &plan.branch);
        }
    }
}
