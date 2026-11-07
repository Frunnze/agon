use orchestration_core::repository_address::{
    AddressProblem, parse_repository_address,
};
use proptest::prelude::*;

use crate::address_strategies::{
    GIT_SUFFIX, canonical_address, host, path_part,
};

const MAXIMUM_GIT_SUFFIXES: usize = 5;
const MAXIMUM_TRAILING_SLASHES: usize = 3;
const PATH_SEPARATOR: &str = "/";
const LOCAL_ADDRESS_PREFIX: &str = "local:";
const ANY_REPOSITORY_NAME: &str = "[A-Za-z0-9_][A-Za-z0-9._-]{0,12}";
const SHAPED_ADDRESS: &str =
    "(https://|git@)?[a-zA-Z0-9.:/_-]{0,30}(\\.git){0,3}/{0,2}";

fn parse_twice(address: &str) -> Result<String, AddressProblem> {
    let parsed_once = parse_repository_address(address)?;
    parse_repository_address(&parsed_once)
}

proptest! {
    #[test]
    fn test_parse_repository_address_property_drops_every_git_suffix(
        address in canonical_address(),
        suffix_count in 1..=MAXIMUM_GIT_SUFFIXES,
        trailing_slash_count in 0..MAXIMUM_TRAILING_SLASHES,
    ) {
        let suffixes = GIT_SUFFIX.repeat(suffix_count);
        let slashes = PATH_SEPARATOR.repeat(trailing_slash_count);
        let forms = [
            format!("{address}{suffixes}{slashes}"),
            format!("https://{address}{suffixes}{slashes}"),
        ];

        for form in forms {
            let parsed = parse_repository_address(&form);
            prop_assert_eq!(parsed, Ok(address.clone()));
        }
    }

    #[test]
    fn test_parse_repository_address_property_reparsing_changes_nothing(
        host in host(),
        owner in path_part(),
        repository in ANY_REPOSITORY_NAME,
        suffix_count in 0..=MAXIMUM_GIT_SUFFIXES,
    ) {
        let suffixes = GIT_SUFFIX.repeat(suffix_count);
        let address = format!("git@{host}:{owner}/{repository}{suffixes}");

        let parsed_once = parse_repository_address(&address);

        prop_assert!(parsed_once.is_ok());
        prop_assert_eq!(parse_twice(&address), parsed_once);
    }

    #[test]
    fn test_parse_repository_address_property_clone_url_reads_back(
        host in host(),
        owner in path_part(),
        repository in ANY_REPOSITORY_NAME,
    ) {
        let address = format!("{host}/{owner}/{repository}");
        let canonical = parse_repository_address(&address)?;
        let clone_url = format!("https://{canonical}{GIT_SUFFIX}");

        let read_back = parse_repository_address(&clone_url);

        prop_assert_eq!(read_back, Ok(canonical));
    }

    #[test]
    fn test_parse_repository_address_property_only_suffixes_is_no_name(
        host in host(),
        owner in path_part(),
        suffix_count in 1..=MAXIMUM_GIT_SUFFIXES,
    ) {
        let suffixes = GIT_SUFFIX.repeat(suffix_count);
        let address = format!("{host}/{owner}/{suffixes}");

        let parsed = parse_repository_address(&address);

        let expected = AddressProblem::InvalidPathPart {
            part: String::new(),
        };
        prop_assert_eq!(parsed, Err(expected));
    }

    #[test]
    fn test_parse_repository_address_fuzz_canonical_name_has_no_git_suffix(
        address in SHAPED_ADDRESS,
    ) {
        let parsed = parse_repository_address(&address);

        if let Ok(canonical) = &parsed
            && !canonical.starts_with(LOCAL_ADDRESS_PREFIX)
        {
            prop_assert!(!canonical.ends_with(GIT_SUFFIX));
            prop_assert_eq!(parse_twice(&address), parsed.clone());
        }
    }
}
