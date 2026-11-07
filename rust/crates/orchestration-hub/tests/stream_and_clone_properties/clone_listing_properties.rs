use std::collections::BTreeSet;
use std::fs;
use std::path::Path;

use orchestration_hub::cached_clones::{
    cached_clone_folder, decode_clone_folder_name, list_cached_repositories,
};
use proptest::collection::{btree_set, vec};
use proptest::prelude::*;

const GIT_DIRECTORY_NAME: &str = ".git";
const LISTING_CASES: u32 = 48;
const LARGEST_CLONE_COUNT: usize = 5;
const SHORTENED_NAME_SEPARATOR: char = '.';
const JUNK_FOLDER_NAMES: [&str; 5] =
    ["Not An Address", "_zz", "_4", "UPPER", "a_2F"];

type Outcome = Result<(), TestCaseError>;

fn any_address() -> impl Strategy<Value = String> {
    "[a-z0-9-]{1,8}\\.[a-z]{2,3}/[A-Za-z0-9é_.-]{1,8}/[A-Za-z0-9_.-]{1,8}"
}

fn any_addresses() -> impl Strategy<Value = BTreeSet<String>> {
    btree_set(any_address(), 0..LARGEST_CLONE_COUNT)
}

fn fail(problem: &impl ToString) -> TestCaseError {
    TestCaseError::fail(problem.to_string())
}

fn make_clone(cache_root: &Path, address: &str) -> Outcome {
    let folder = cached_clone_folder(cache_root, address);
    let git_directory = folder.join(GIT_DIRECTORY_NAME);
    fs::create_dir_all(git_directory).map_err(|problem| fail(&problem))
}

fn list_or_fail(cache_root: &Path) -> Result<Vec<String>, TestCaseError> {
    list_cached_repositories(cache_root).map_err(|problem| fail(&problem))
}

proptest! {
    #[test]
    fn test_cached_clone_folder_property_addresses_get_their_own_folder(
        first in any::<String>(),
        second in any::<String>(),
    ) {
        let cache_root = Path::new("runner/cache");

        let first_folder = cached_clone_folder(cache_root, &first);
        let second_folder = cached_clone_folder(cache_root, &second);

        prop_assert_eq!(first_folder == second_folder, first == second);
    }

    #[test]
    fn test_cached_clone_folder_property_folder_name_reads_back(
        address in ".+",
    ) {
        let cache_root = Path::new("runner/cache");

        let folder = cached_clone_folder(cache_root, &address);

        let folder_name = folder.file_name().and_then(|name| name.to_str());
        let decoded = folder_name.and_then(decode_clone_folder_name);
        let is_shortened = folder_name
            .is_some_and(|name| name.contains(SHORTENED_NAME_SEPARATOR));
        prop_assert_eq!(decoded, (!is_shortened).then_some(address));
        prop_assert_ne!(folder.as_path(), cache_root);
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LISTING_CASES))]

    #[test]
    fn test_list_cached_repositories_property_lists_clones_in_order(
        clones in any_addresses(),
        unfinished in any_addresses(),
    ) {
        let cache = tempfile::tempdir().map_err(|problem| fail(&problem))?;
        for address in &clones {
            make_clone(cache.path(), address)?;
        }
        for address in unfinished.difference(&clones) {
            let folder = cached_clone_folder(cache.path(), address);
            fs::create_dir_all(folder).map_err(|problem| fail(&problem))?;
        }

        let listed = list_or_fail(cache.path())?;

        let expected: Vec<String> = clones.into_iter().collect();
        prop_assert_eq!(listed, expected);
    }

    #[test]
    fn test_list_cached_repositories_property_skips_junk_and_files(
        clones in any_addresses(),
        file_addresses in vec(any_address(), 0..3),
        junk_picks in vec(0..JUNK_FOLDER_NAMES.len(), 0..3),
    ) {
        let cache = tempfile::tempdir().map_err(|problem| fail(&problem))?;
        for address in &clones {
            make_clone(cache.path(), address)?;
        }
        for pick in junk_picks {
            let junk = cache.path().join(JUNK_FOLDER_NAMES[pick]);
            fs::create_dir_all(junk.join(GIT_DIRECTORY_NAME))
                .map_err(|problem| fail(&problem))?;
        }
        for address in &file_addresses {
            if clones.contains(address) {
                continue;
            }
            let file = cached_clone_folder(cache.path(), address);
            fs::write(file, "not a clone").map_err(|problem| fail(&problem))?;
        }

        let listed = list_or_fail(cache.path())?;

        let expected: Vec<String> = clones.into_iter().collect();
        prop_assert_eq!(listed, expected);
    }

    #[test]
    fn test_list_cached_repositories_property_lists_nothing_without_clones(
        missing_parts in vec("[a-z]{1,6}", 1..3),
        address in any_address(),
    ) {
        let cache = tempfile::tempdir().map_err(|problem| fail(&problem))?;
        let missing_root = cache.path().join(missing_parts.join("/"));
        let gitfile_clone = cached_clone_folder(cache.path(), &address);
        fs::create_dir_all(&gitfile_clone).map_err(|problem| fail(&problem))?;
        fs::write(gitfile_clone.join(GIT_DIRECTORY_NAME), "gitdir: x")
            .map_err(|problem| fail(&problem))?;

        prop_assert_eq!(list_or_fail(&missing_root)?, Vec::<String>::new());
        prop_assert_eq!(list_or_fail(cache.path())?, Vec::<String>::new());
    }
}
