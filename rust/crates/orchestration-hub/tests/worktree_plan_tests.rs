mod worktree_support;

use std::path::{Component, Path};

use orchestration_hub::branch_names::is_valid_branch_name;
use orchestration_hub::slugs::slugify;
use orchestration_hub::worktree_plan::{WorktreeLifetime, WorktreeRequest};
use proptest::prelude::*;
use worktree_support::{
    CACHE_ROOT, WORKTREES_ROOT, any_canonical_address, any_hostile_title,
    any_lifetime, any_task_id, plan_or_fail, repository_at, request_for,
};

fn is_single_plain_component(path: &Path, parent: &Path) -> bool {
    let Ok(relative) = path.strip_prefix(parent) else {
        return false;
    };
    let components: Vec<Component> = relative.components().collect();
    let is_plain = matches!(components.as_slice(), [Component::Normal(_)]);
    is_plain && path.parent() == Some(parent)
}

fn is_cached_clone_character(character: char) -> bool {
    character.is_ascii_lowercase()
        || character.is_ascii_digit()
        || character == '-'
        || character == '_'
}

fn file_name_of(path: &Path) -> String {
    path.file_name()
        .map(|name| name.to_string_lossy().to_string())
        .unwrap_or_default()
}

fn expected_folder_name(title: &str, request: &WorktreeRequest) -> String {
    let title_slug = slugify(title);
    let readable_part = if title_slug.is_empty() {
        "task".to_string()
    } else {
        title_slug
    };
    let task_part = format!("{readable_part}-{}", request.task_id.0.simple());
    match request.lifetime {
        WorktreeLifetime::PerTask => task_part,
        WorktreeLifetime::PerJobRun { run_number } => {
            format!("{task_part}-run-{run_number}")
        }
    }
}

proptest! {
    #[test]
    fn test_plan_worktree_property_paths_stay_inside_the_roots(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
    ) {
        let repositories = vec![repository_at(&address)];
        let request = request_for(task_id, &title, lifetime, repositories);

        let plan = plan_or_fail(&request)?;

        let task_folder = plan.task_folder.as_path();
        let worktrees_root = Path::new(WORKTREES_ROOT);
        let cache_root = Path::new(CACHE_ROOT);
        prop_assert!(is_single_plain_component(task_folder, worktrees_root));
        for repository in &plan.repositories {
            let worktree = repository.worktree.as_path();
            let cached_clone = repository.cached_clone.as_path();
            prop_assert!(is_single_plain_component(worktree, task_folder));
            prop_assert!(is_single_plain_component(cached_clone, cache_root));
        }
    }

    #[test]
    fn test_plan_worktree_property_branch_names_are_valid(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
    ) {
        let request = request_for(task_id, &title, lifetime, vec![]);

        let plan = plan_or_fail(&request)?;

        prop_assert!(plan.branch.starts_with("task/"));
        prop_assert!(is_valid_branch_name(&plan.branch));
    }

    #[test]
    fn test_plan_worktree_property_names_follow_the_task(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
    ) {
        let request = request_for(task_id, &title, lifetime, vec![]);

        let plan = plan_or_fail(&request)?;

        let folder_name = expected_folder_name(&title, &request);
        let expected_folder = Path::new(WORKTREES_ROOT).join(&folder_name);
        prop_assert_eq!(&plan.task_folder, &expected_folder);
        prop_assert_eq!(plan.branch, format!("task/{folder_name}"));
    }

    #[test]
    fn test_plan_worktree_property_job_runs_get_fresh_folders_and_branches(
        task_id in any_task_id(),
        title in any_hostile_title(),
        first_run in any::<u32>(),
        second_run in any::<u32>(),
    ) {
        prop_assume!(first_run != second_run);
        let first_lifetime =
            WorktreeLifetime::PerJobRun { run_number: first_run };
        let second_lifetime =
            WorktreeLifetime::PerJobRun { run_number: second_run };

        let first_request =
            request_for(task_id, &title, first_lifetime, vec![]);
        let second_request =
            request_for(task_id, &title, second_lifetime, vec![]);

        let first = plan_or_fail(&first_request)?;
        let second = plan_or_fail(&second_request)?;

        prop_assert_ne!(first.task_folder, second.task_folder);
        prop_assert_ne!(first.branch, second.branch);
    }

    #[test]
    fn test_plan_worktree_property_retry_gives_the_same_plan(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
    ) {
        let repositories = vec![repository_at(&address)];
        let request = request_for(task_id, &title, lifetime, repositories);

        prop_assert_eq!(plan_or_fail(&request)?, plan_or_fail(&request)?);
    }

    #[test]
    fn test_plan_worktree_property_distinct_tasks_never_share_a_branch(
        first_task in any_task_id(),
        second_task in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
    ) {
        prop_assume!(first_task != second_task);
        let first_request = request_for(first_task, &title, lifetime, vec![]);
        let second_request =
            request_for(second_task, &title, lifetime, vec![]);

        let first = plan_or_fail(&first_request)?;
        let second = plan_or_fail(&second_request)?;

        prop_assert_ne!(first.branch, second.branch);
        prop_assert_ne!(first.task_folder, second.task_folder);
    }

    #[test]
    fn test_plan_worktree_property_distinct_addresses_get_distinct_clones(
        task_id in any_task_id(),
        lifetime in any_lifetime(),
        first_address in any_canonical_address(),
        second_address in any_canonical_address(),
    ) {
        prop_assume!(first_address != second_address);
        let first_repositories = vec![repository_at(&first_address)];
        let second_repositories = vec![repository_at(&second_address)];

        let first_request =
            request_for(task_id, "a", lifetime, first_repositories);
        let second_request =
            request_for(task_id, "a", lifetime, second_repositories);

        let first = plan_or_fail(&first_request)?;
        let second = plan_or_fail(&second_request)?;

        let first_clone = &first.repositories[0].cached_clone;
        let second_clone = &second.repositories[0].cached_clone;
        let has_only_safe_characters = file_name_of(first_clone)
            .chars()
            .all(is_cached_clone_character);
        prop_assert_ne!(first_clone, second_clone);
        prop_assert!(has_only_safe_characters);
    }
}
