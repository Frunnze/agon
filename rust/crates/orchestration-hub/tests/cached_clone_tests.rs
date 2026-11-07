use std::error::Error;
use std::fs;

use orchestration_hub::cached_clones::{
    cached_clone_folder, decode_clone_folder_name, encode_clone_folder_name,
    list_cached_repositories,
};
use proptest::prelude::*;

type TestResult<T> = Result<T, Box<dyn Error>>;

const GIT_DIRECTORY_NAME: &str = ".git";
const SHORTENED_NAME_SEPARATOR: char = '.';

fn is_plain_name(name: &str) -> bool {
    name.chars().all(|character| {
        character.is_ascii_lowercase()
            || character.is_ascii_digit()
            || character == '-'
            || character == '_'
    })
}

proptest! {
    #[test]
    fn test_decode_clone_folder_name_property_inverts_the_encoding(
        address in any::<String>(),
    ) {
        let folder_name = encode_clone_folder_name(&address);

        let is_shortened = folder_name.contains(SHORTENED_NAME_SEPARATOR);
        let expected = (!is_shortened).then_some(address);
        prop_assert_eq!(decode_clone_folder_name(&folder_name), expected);
    }

    #[test]
    fn test_encode_clone_folder_name_property_keeps_plain_characters(
        address in any::<String>(),
    ) {
        let folder_name = encode_clone_folder_name(&address);

        let Some((start, hash)) =
            folder_name.split_once(SHORTENED_NAME_SEPARATOR)
        else {
            prop_assert!(is_plain_name(&folder_name));
            return Ok(());
        };
        prop_assert!(is_plain_name(start));
        let is_hash = hash
            .chars()
            .all(|character| matches!(character, '0'..='9' | 'a'..='f'));
        prop_assert!(is_hash, "{hash}");
    }

    #[test]
    fn test_decode_clone_folder_name_fuzz_accepts_only_canonical_names(
        folder_name in any::<String>(),
    ) {
        if let Some(address) = decode_clone_folder_name(&folder_name) {
            prop_assert_eq!(encode_clone_folder_name(&address), folder_name);
        }
    }

    #[test]
    fn test_cached_clone_folder_property_stays_inside_the_cache_root(
        address in ".+",
    ) {
        let cache_root = std::path::Path::new("/runner/cache");

        let folder = cached_clone_folder(cache_root, &address);

        prop_assert_eq!(folder.parent(), Some(cache_root));
    }
}

#[test]
fn test_list_cached_repositories_lists_only_git_clones() -> TestResult<()> {
    let cache_root = tempfile::tempdir()?;
    for address in ["github.com/acme/app", "github.com/acme/api"] {
        let clone = cached_clone_folder(cache_root.path(), address);
        fs::create_dir_all(clone.join(GIT_DIRECTORY_NAME))?;
    }
    let unfinished = cached_clone_folder(cache_root.path(), "github.com/b/c");
    fs::create_dir_all(unfinished)?;
    fs::create_dir_all(cache_root.path().join("Not An Address"))?;

    let listed = list_cached_repositories(cache_root.path())?;

    assert_eq!(listed, ["github.com/acme/api", "github.com/acme/app"]);
    Ok(())
}

#[test]
fn test_list_cached_repositories_is_empty_before_the_first_clone()
-> TestResult<()> {
    let runner_data = tempfile::tempdir()?;

    let listed = list_cached_repositories(&runner_data.path().join("cache"))?;

    assert_eq!(listed, Vec::<String>::new());
    Ok(())
}
