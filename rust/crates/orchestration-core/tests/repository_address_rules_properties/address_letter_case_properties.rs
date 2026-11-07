use orchestration_core::repository_address::{
    AddressProblem, parse_repository_address,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::address_strategies::{canonical_address, host, path_part};

const SUPPORTED_SCHEME: &str = "https";
const OTHER_SCHEME: &str = "[A-Za-z][A-Za-z0-9+.-]{0,8}";
const MAXIMUM_CASE_CHOICES: usize = 12;
const LOCAL_ADDRESS_PREFIX: &str = "local:";
const PATH_SEPARATOR: char = '/';

fn scramble_letter_case(text: &str, uppercase_choices: &[bool]) -> String {
    let mut scrambled = String::new();
    let choices = uppercase_choices.iter().cycle();
    for (character, is_uppercase) in text.chars().zip(choices) {
        if *is_uppercase {
            scrambled.push(character.to_ascii_uppercase());
        } else {
            scrambled.push(character);
        }
    }
    scrambled
}

fn case_choices() -> impl Strategy<Value = Vec<bool>> {
    vec(any::<bool>(), 1..MAXIMUM_CASE_CHOICES)
}

fn any_scheme() -> impl Strategy<Value = String> {
    prop_oneof![
        case_choices().prop_map(|uppercase_choices| {
            scramble_letter_case(SUPPORTED_SCHEME, &uppercase_choices)
        }),
        OTHER_SCHEME,
    ]
}

proptest! {
    #[test]
    fn test_remove_address_prefix_property_https_is_read_in_any_case(
        address in canonical_address(),
        uppercase_choices in case_choices(),
    ) {
        let scheme =
            scramble_letter_case(SUPPORTED_SCHEME, &uppercase_choices);
        let with_scheme = format!("{scheme}://{address}");

        let parsed = parse_repository_address(&with_scheme);

        prop_assert_eq!(parsed, Ok(address));
    }

    #[test]
    fn test_remove_address_prefix_property_refuses_only_non_https_schemes(
        scheme in any_scheme(),
        address in canonical_address(),
    ) {
        let with_scheme = format!("{scheme}://{address}");

        let parsed = parse_repository_address(&with_scheme);

        let expected = if scheme.eq_ignore_ascii_case(SUPPORTED_SCHEME) {
            Ok(address)
        } else {
            Err(AddressProblem::UnsupportedScheme { scheme })
        };
        prop_assert_eq!(parsed, expected);
    }

    #[test]
    fn test_remove_address_prefix_property_scheme_case_never_matters(
        scheme in any_scheme(),
        address in canonical_address(),
        uppercase_choices in case_choices(),
    ) {
        let lower_scheme = scheme.to_ascii_lowercase();
        let mixed_scheme = scramble_letter_case(&scheme, &uppercase_choices);

        let lower_parsed =
            parse_repository_address(&format!("{lower_scheme}://{address}"));
        let mixed_parsed =
            parse_repository_address(&format!("{mixed_scheme}://{address}"));

        prop_assert_eq!(lower_parsed.is_ok(), mixed_parsed.is_ok());
        prop_assert_eq!(lower_parsed.ok(), mixed_parsed.ok());
    }

    #[test]
    fn test_parse_repository_address_property_lowercases_the_host(
        host in host(),
        owner in path_part(),
        repository in path_part(),
        uppercase_choices in case_choices(),
    ) {
        let mixed_host = scramble_letter_case(&host, &uppercase_choices);
        let address = format!("{mixed_host}/{owner}/{repository}");

        let parsed = parse_repository_address(&address);

        prop_assert_eq!(parsed, Ok(format!("{host}/{owner}/{repository}")));
    }

    #[test]
    fn test_parse_repository_address_property_host_case_names_one_repository(
        host in host(),
        owner in path_part(),
        repository in path_part(),
        first_choices in case_choices(),
        second_choices in case_choices(),
    ) {
        let first_host = scramble_letter_case(&host, &first_choices);
        let second_host = scramble_letter_case(&host, &second_choices);
        let https_form = format!("https://{first_host}/{owner}/{repository}");
        let git_at_form = format!("git@{second_host}:{owner}/{repository}");

        let https_parsed = parse_repository_address(&https_form);
        let git_at_parsed = parse_repository_address(&git_at_form);

        prop_assert!(https_parsed.is_ok());
        prop_assert_eq!(https_parsed, git_at_parsed);
    }

    #[test]
    fn test_parse_repository_address_property_owner_and_repository_keep_case(
        host in host(),
        owner in path_part(),
        repository in path_part(),
        uppercase_choices in case_choices(),
    ) {
        let mixed_owner = scramble_letter_case(&owner, &uppercase_choices);
        let mixed_repository =
            scramble_letter_case(&repository, &uppercase_choices);
        let address = format!("{host}/{mixed_owner}/{mixed_repository}");

        let parsed = parse_repository_address(&address);

        prop_assert_eq!(parsed, Ok(address));
    }

    #[test]
    fn test_parse_repository_address_fuzz_canonical_host_is_lowercase(
        address in "(https?://|HTTPS://|git@)?[A-Za-z0-9.:/_-]{0,30}",
    ) {
        let parsed = parse_repository_address(&address);

        if let Ok(canonical) = parsed
            && !canonical.starts_with(LOCAL_ADDRESS_PREFIX)
        {
            let host = canonical.split(PATH_SEPARATOR).next();
            let lowercase_host = host.map(str::to_ascii_lowercase);
            prop_assert_eq!(host, lowercase_host.as_deref());
        }
    }
}
