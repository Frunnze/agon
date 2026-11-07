use std::path::PathBuf;

use orchestration_hub::cached_clones::cached_clone_folder;
use orchestration_hub::clone_source::{ADDRESS_PLACEHOLDER, CloneSource};
use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::worktree_plan::{
    RepositoryWorktreePlan, WorktreeLifetime, WorktreeRequest,
};
use proptest::prelude::*;

use crate::worktree_support::{
    CACHE_ROOT, any_canonical_address, any_hostile_title, any_lifetime,
    any_task_id, plan_or_fail, repository_at, request_for,
};

const TERMINAL_PROMPT_VARIABLE: &str = "GIT_TERMINAL_PROMPT";
const SWITCHED_OFF: &str = "0";

fn displayed(path: &std::path::Path) -> String {
    path.display().to_string()
}

fn plan_one(
    request: &WorktreeRequest,
) -> Result<RepositoryWorktreePlan, TestCaseError> {
    let plan = plan_or_fail(request)?;
    plan.repositories
        .first()
        .cloned()
        .ok_or_else(|| TestCaseError::fail("the plan has no repository"))
}

fn any_option_like_template() -> impl Strategy<Value = String> {
    prop_oneof![
        Just(format!("--upload-pack=touch{ADDRESS_PLACEHOLDER}")),
        Just(format!("-u{ADDRESS_PLACEHOLDER}")),
        Just(format!("--config=a.b={ADDRESS_PLACEHOLDER}")),
        Just(format!("https://{ADDRESS_PLACEHOLDER}.git")),
    ]
}

fn prompt_is_off(command: &CommandSpecification) -> bool {
    let prompt = command.environment.get(TERMINAL_PROMPT_VARIABLE);
    prompt.map(String::as_str) == Some(SWITCHED_OFF)
}

proptest! {
    #[test]
    fn test_clone_command_property_clones_without_checkout_into_cache(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
    ) {
        let repositories = vec![repository_at(&address)];
        let request = request_for(task_id, &title, lifetime, repositories);

        let planned = plan_one(&request)?;

        let cached_clone =
            cached_clone_folder(&PathBuf::from(CACHE_ROOT), &address);
        let clone_url = format!("https://{address}.git");
        let expected = vec![
            "clone".to_owned(),
            "--no-checkout".to_owned(),
            "--".to_owned(),
            clone_url,
            displayed(&cached_clone),
        ];
        prop_assert_eq!(&planned.clone_command.arguments, &expected);
        prop_assert_eq!(planned.cached_clone, cached_clone);
    }

    #[test]
    fn test_clone_command_property_runs_anywhere_without_prompts(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
    ) {
        let repositories = vec![repository_at(&address)];
        let request = request_for(task_id, &title, lifetime, repositories);

        let planned = plan_one(&request)?;

        prop_assert_eq!(&planned.clone_command.program, "git");
        prop_assert_eq!(&planned.clone_command.working_directory, &None);
        prop_assert!(prompt_is_off(&planned.clone_command));
    }

    #[test]
    fn test_clone_command_property_option_like_urls_stay_repositories(
        task_id in any_task_id(),
        address in any_canonical_address(),
        template in any_option_like_template(),
    ) {
        let clone_source = CloneSource::from_template(&template)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
        let request = WorktreeRequest {
            clone_source,
            ..request_for(
                task_id,
                "Fix",
                WorktreeLifetime::PerTask,
                vec![repository_at(&address)],
            )
        };

        let planned = plan_one(&request)?;

        let arguments = &planned.clone_command.arguments;
        let separator = arguments.iter().position(|argument| argument == "--");
        let clone_url = template.replacen(ADDRESS_PLACEHOLDER, &address, 1);
        let url_position =
            arguments.iter().position(|argument| *argument == clone_url);
        prop_assert_eq!(separator, Some(2));
        prop_assert_eq!(url_position, Some(3));
        prop_assert_eq!(arguments.len(), 5);
    }

    #[test]
    fn test_fetch_command_property_fetches_and_prunes_origin_in_the_clone(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
    ) {
        let repositories = vec![repository_at(&address)];
        let request = request_for(task_id, &title, lifetime, repositories);

        let planned = plan_one(&request)?;

        let expected = vec![
            "fetch".to_owned(),
            "--prune".to_owned(),
            "origin".to_owned(),
        ];
        prop_assert_eq!(&planned.fetch_command.arguments, &expected);
        prop_assert_eq!(
            planned.fetch_command.working_directory.as_ref(),
            Some(&planned.cached_clone)
        );
        prop_assert!(prompt_is_off(&planned.fetch_command));
    }

    #[test]
    fn test_fetch_command_property_is_the_same_for_every_task(
        (first_task, second_task) in (any_task_id(), any_task_id()),
        (first_title, second_title) in
            (any_hostile_title(), any_hostile_title()),
        (first_lifetime, second_lifetime) in (any_lifetime(), any_lifetime()),
        address in any_canonical_address(),
    ) {
        let first = request_for(
            first_task,
            &first_title,
            first_lifetime,
            vec![repository_at(&address)],
        );
        let second = request_for(
            second_task,
            &second_title,
            second_lifetime,
            vec![repository_at(&address)],
        );

        let first_planned = plan_one(&first)?;
        let second_planned = plan_one(&second)?;

        prop_assert_eq!(
            first_planned.fetch_command,
            second_planned.fetch_command
        );
        prop_assert_eq!(
            first_planned.clone_command,
            second_planned.clone_command
        );
    }

    #[test]
    fn test_add_worktree_command_property_branches_off_the_remote_default(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
        default_branch in "[a-z]{1,8}(/[a-z0-9_]{1,8}){0,2}",
    ) {
        let mut repository = repository_at(&address);
        repository.default_branch = default_branch.clone();
        let request = request_for(task_id, &title, lifetime, vec![repository]);
        let plan = plan_or_fail(&request)?;
        let planned = &plan.repositories[0];

        let expected = vec![
            "worktree".to_owned(),
            "add".to_owned(),
            "-b".to_owned(),
            plan.branch.clone(),
            displayed(&planned.worktree),
            format!("origin/{default_branch}"),
        ];
        prop_assert_eq!(&planned.add_worktree_command.arguments, &expected);
        prop_assert_eq!(
            planned.add_worktree_command.working_directory.as_ref(),
            Some(&planned.cached_clone)
        );
    }

    #[test]
    fn test_add_worktree_command_property_no_argument_reads_as_an_option(
        task_id in any_task_id(),
        title in prop_oneof![
            any_hostile_title(),
            Just("--force".to_owned()),
            Just("-b".to_owned()),
        ],
        lifetime in any_lifetime(),
        address in any_canonical_address(),
    ) {
        let request = request_for(
            task_id,
            &title,
            lifetime,
            vec![repository_at(&address)],
        );

        let planned = plan_one(&request)?;

        let named_arguments = &planned.add_worktree_command.arguments[3..];
        for argument in named_arguments {
            prop_assert!(!argument.starts_with('-'), "{}", argument);
        }
    }

    #[test]
    fn test_add_worktree_command_property_worktree_sits_in_the_task_folder(
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
        let worktree_argument = &planned.add_worktree_command.arguments[4];

        prop_assert_eq!(worktree_argument, &displayed(&planned.worktree));
        prop_assert_eq!(
            planned.worktree.parent(),
            Some(plan.task_folder.as_path())
        );
    }
}
