use std::collections::BTreeSet;
use std::fs;
use std::path::{Path, PathBuf};

use orchestration_hub::cached_clones::{
    cached_clone_folder, encode_clone_folder_name, list_cached_repositories,
    record_clone_address,
};
use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::worktree_plan::WorktreeLifetime;
use orchestration_hub::worktrees::create_worktrees;
use proptest::collection::btree_set;
use proptest::prelude::*;

use crate::clone_name_support::{any_address, any_long_address};
use crate::git_support::{RunnerFolders, create_origin, plan_for};
use crate::target_folders::{create_target_folder, fail_with};

const GIT_DIRECTORY_NAME: &str = ".git";
const SHORT_ADDRESS_PATTERN: &str =
    "[a-z0-9-]{1,8}\\.[a-z]{2,3}/[a-z]{1,8}/[a-z]{1,8}";
const LONG_REPOSITORY_NAME_PATTERN: &str = "[A-Z_]{90,100}";
const LISTING_CASES: u32 = 32;
const GIT_CASES: u32 = 3;
const ORIGIN_OWNER: &str = "local.test/acme";

type Outcome = Result<(), TestCaseError>;

fn make_clone(
    cache_root: &Path,
    address: &str,
) -> Result<PathBuf, TestCaseError> {
    let folder = cached_clone_folder(cache_root, address);
    fs::create_dir_all(folder.join(GIT_DIRECTORY_NAME))
        .map_err(|problem| fail_with(&problem))?;
    Ok(folder)
}

fn make_recorded_clone(cache_root: &Path, address: &str) -> Outcome {
    let folder = make_clone(cache_root, address)?;
    record_clone_address(&folder, address)
        .map_err(|problem| fail_with(&problem))
}

fn list_or_fail(cache_root: &Path) -> Result<Vec<String>, TestCaseError> {
    list_cached_repositories(cache_root).map_err(|problem| fail_with(&problem))
}

fn is_shortened(address: &str) -> bool {
    encode_clone_folder_name(address).contains('.')
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LISTING_CASES))]

    #[test]
    fn test_list_cached_repositories_property_lists_long_recorded_addresses(
        addresses in btree_set(any_long_address(), 1..4),
    ) {
        let cache = create_target_folder()?;
        for address in &addresses {
            make_recorded_clone(cache.path(), address)?;
        }

        let listed = list_or_fail(cache.path())?;

        let expected: Vec<String> = addresses.into_iter().collect();
        prop_assert_eq!(listed, expected);
    }

    #[test]
    fn test_list_cached_repositories_property_plain_names_need_no_record(
        recorded in btree_set(SHORT_ADDRESS_PATTERN, 0..3),
        unrecorded in btree_set(SHORT_ADDRESS_PATTERN, 0..3),
    ) {
        let cache = create_target_folder()?;
        for address in &recorded {
            make_recorded_clone(cache.path(), address)?;
        }
        for address in unrecorded.difference(&recorded) {
            make_clone(cache.path(), address)?;
        }

        let listed = list_or_fail(cache.path())?;

        let expected: BTreeSet<String> =
            recorded.union(&unrecorded).cloned().collect();
        let expected: Vec<String> = expected.into_iter().collect();
        prop_assert_eq!(listed, expected);
    }

    #[test]
    fn test_list_cached_repositories_property_ignores_foreign_records(
        address in any_long_address(),
        foreign_address in any_address(),
    ) {
        prop_assume!(is_shortened(&address));
        prop_assume!(
            encode_clone_folder_name(&foreign_address)
                != encode_clone_folder_name(&address)
        );
        let cache = create_target_folder()?;
        let folder = make_clone(cache.path(), &address)?;
        record_clone_address(&folder, &foreign_address)
            .map_err(|problem| fail_with(&problem))?;

        let listed = list_or_fail(cache.path())?;

        prop_assert_eq!(listed, Vec::<String>::new());
    }

    #[test]
    fn test_record_clone_address_property_any_address_reads_back(
        address in any_address(),
    ) {
        prop_assume!(!address.is_empty());
        let cache = create_target_folder()?;
        make_recorded_clone(cache.path(), &address)?;

        prop_assert_eq!(list_or_fail(cache.path())?, vec![address]);
    }

    #[test]
    fn test_record_clone_address_property_recording_again_changes_nothing(
        address in any_address(),
        times in 1_usize..4,
    ) {
        prop_assume!(!address.is_empty());
        let cache = create_target_folder()?;
        let folder = make_clone(cache.path(), &address)?;
        for _ in 0..times {
            record_clone_address(&folder, &address)
                .map_err(|problem| fail_with(&problem))?;
        }

        prop_assert_eq!(list_or_fail(cache.path())?, vec![address]);
    }

    #[test]
    fn test_record_clone_address_property_missing_clone_folder_fails(
        address in any_address(),
    ) {
        prop_assume!(!address.is_empty());
        let cache = create_target_folder()?;
        let folder = cached_clone_folder(cache.path(), &address);

        let recorded = record_clone_address(&folder, &address);

        prop_assert!(recorded.is_err());
        prop_assert_eq!(list_or_fail(cache.path())?, Vec::<String>::new());
    }
}

fn runner_folders() -> Result<RunnerFolders, TestCaseError> {
    let temporary = create_target_folder()?;
    Ok(RunnerFolders {
        cache_root: temporary.path().join("cache"),
        worktrees_root: temporary.path().join("worktrees"),
        temporary,
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GIT_CASES))]

    #[test]
    fn test_list_cached_repositories_property_new_long_clones_are_listed(
        repository_name in LONG_REPOSITORY_NAME_PATTERN,
        task_number in 1_u128..1000,
    ) {
        let folders = runner_folders()?;
        let origin = create_origin(&folders, &repository_name)
            .map_err(|problem| fail_with(&problem))?;
        let task_id = crate::git_support::numbered_task_id(task_number)
            .map_err(|problem| fail_with(&problem))?;
        let lifetime = WorktreeLifetime::PerTask;
        let plan = plan_for(&folders, task_id, "long", lifetime, &[origin])
            .map_err(|problem| fail_with(&problem))?;

        create_worktrees(&plan, &CloneLocks::default())
            .map_err(|problem| fail_with(&problem))?;

        let address = format!("{ORIGIN_OWNER}/{repository_name}");
        prop_assert!(is_shortened(&address));
        prop_assert_eq!(list_or_fail(&folders.cache_root)?, vec![address]);
    }
}
