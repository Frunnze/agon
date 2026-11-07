use std::fs;
use std::path::{Path, PathBuf};

use orchestration_hub::cached_clones::{
    CLONE_ADDRESS_FILE_NAME, cached_clone_folder, encode_clone_folder_name,
    list_cached_repositories, record_clone_address,
};
use proptest::prelude::*;

use crate::clone_name_support::any_long_address;
use crate::target_folders::{create_target_folder, fail_with};

const GIT_DIRECTORY_NAME: &str = ".git";
const RECORD_CASES: u32 = 24;
const PLAIN_ADDRESS_PATTERN: &str = "[a-z0-9-]{1,8}\\.[a-z]{2,3}/[a-z]{1,8}";
const RECORD_ENDINGS: [&str; 4] = ["\n", " ", "\r\n", "\t"];

type Outcome = Result<(), TestCaseError>;

fn is_shortened(address: &str) -> bool {
    encode_clone_folder_name(address).contains('.')
}

fn any_shortened_address() -> impl Strategy<Value = String> {
    any_long_address()
        .prop_filter("a shortened address", |address| is_shortened(address))
}

fn make_clone(
    cache_root: &Path,
    address: &str,
) -> Result<PathBuf, TestCaseError> {
    let folder = cached_clone_folder(cache_root, address);
    fs::create_dir_all(folder.join(GIT_DIRECTORY_NAME))
        .map_err(|problem| fail_with(&problem))?;
    Ok(folder)
}

fn record(folder: &Path, address: &str) -> Outcome {
    record_clone_address(folder, address)
        .map_err(|problem| fail_with(&problem))
}

fn list_or_fail(cache_root: &Path) -> Result<Vec<String>, TestCaseError> {
    list_cached_repositories(cache_root).map_err(|problem| fail_with(&problem))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RECORD_CASES))]

    #[test]
    fn test_read_clone_address_property_plain_names_ignore_the_record(
        address in PLAIN_ADDRESS_PATTERN,
        other_address in any_shortened_address(),
    ) {
        let cache = create_target_folder()?;
        let folder = make_clone(cache.path(), &address)?;
        record(&folder, &other_address)?;

        prop_assert_eq!(list_or_fail(cache.path())?, vec![address]);
    }

    #[test]
    fn test_read_clone_address_property_folders_without_git_are_skipped(
        address in any_shortened_address(),
    ) {
        let cache = create_target_folder()?;
        let folder = cached_clone_folder(cache.path(), &address);
        fs::create_dir_all(&folder).map_err(|problem| fail_with(&problem))?;
        record(&folder, &address)?;

        prop_assert_eq!(list_or_fail(cache.path())?, Vec::<String>::new());
    }

    #[test]
    fn test_read_clone_address_property_swapped_records_name_nobody(
        first in any_shortened_address(),
        second in any_shortened_address(),
    ) {
        let first_name = encode_clone_folder_name(&first);
        prop_assume!(first_name != encode_clone_folder_name(&second));
        let cache = create_target_folder()?;
        let first_folder = make_clone(cache.path(), &first)?;
        let second_folder = make_clone(cache.path(), &second)?;
        record(&first_folder, &second)?;
        record(&second_folder, &first)?;

        prop_assert_eq!(list_or_fail(cache.path())?, Vec::<String>::new());
    }

    #[test]
    fn test_read_recorded_address_property_unreadable_record_fails(
        address in any_shortened_address(),
    ) {
        let cache = create_target_folder()?;
        let folder = make_clone(cache.path(), &address)?;
        fs::create_dir_all(folder.join(CLONE_ADDRESS_FILE_NAME))
            .map_err(|problem| fail_with(&problem))?;

        prop_assert!(list_cached_repositories(cache.path()).is_err());
    }

    #[test]
    fn test_read_recorded_address_property_record_must_match_exactly(
        address in any_shortened_address(),
        ending in proptest::sample::select(RECORD_ENDINGS.to_vec()),
    ) {
        let cache = create_target_folder()?;
        let folder = make_clone(cache.path(), &address)?;
        let record_file = folder.join(CLONE_ADDRESS_FILE_NAME);
        fs::write(record_file, format!("{address}{ending}"))
            .map_err(|problem| fail_with(&problem))?;

        let listed_with_ending = list_or_fail(cache.path())?;
        record(&folder, &address)?;

        prop_assert_eq!(listed_with_ending, Vec::<String>::new());
        prop_assert_eq!(list_or_fail(cache.path())?, vec![address]);
    }

    #[test]
    fn test_read_recorded_address_property_missing_record_is_no_error(
        address in any_shortened_address(),
        plain_address in PLAIN_ADDRESS_PATTERN,
    ) {
        let cache = create_target_folder()?;
        make_clone(cache.path(), &address)?;
        make_clone(cache.path(), &plain_address)?;

        prop_assert_eq!(list_or_fail(cache.path())?, vec![plain_address]);
    }
}
