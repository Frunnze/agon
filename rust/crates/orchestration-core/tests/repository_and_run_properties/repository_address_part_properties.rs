use orchestration_core::repository_address::{
    AddressProblem, parse_repository_address,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::address_strategies::{host, host_label, path_part};

const MAXIMUM_LABELS: usize = 4;
const RESERVED_PATH_PARTS: [&str; 2] = [".", ".."];
const ASCII_HOST_CHARACTERS: &str = "[A-Za-z0-9-]";
const ASCII_PATH_CHARACTERS: &str = "[A-Za-z0-9_-]";
const DOTTED_NAME: &str = "[a-z0-9]{0,3}\\.{1,3}[a-z0-9]{0,3}";

fn invalid_host(host: &str) -> Result<String, AddressProblem> {
    Err(AddressProblem::InvalidHost {
        host: host.to_owned(),
    })
}

fn invalid_part(part: &str) -> Result<String, AddressProblem> {
    Err(AddressProblem::InvalidPathPart {
        part: part.to_owned(),
    })
}

fn is_structural(character: char) -> bool {
    matches!(character, '/' | '.')
}

fn is_host_character(character: char) -> bool {
    character.is_ascii_alphanumeric() || character == '-'
}

fn is_path_character(character: char) -> bool {
    character.is_ascii_alphanumeric() || matches!(character, '-' | '_' | '.')
}

proptest! {
    #[test]
    fn test_validate_host_property_refuses_a_host_without_a_dot(
        label in host_label(),
        owner in path_part(),
        repository in path_part(),
    ) {
        let address = format!("{label}/{owner}/{repository}");

        let parsed = parse_repository_address(&address);

        prop_assert_eq!(parsed, invalid_host(&label));
    }

    #[test]
    fn test_validate_host_property_refuses_empty_labels(
        labels in vec(host_label(), 2..MAXIMUM_LABELS),
        empty_position in any::<prop::sample::Index>(),
        repository in path_part(),
    ) {
        let mut spaced_labels = labels.clone();
        let position = empty_position.index(labels.len() + 1);
        spaced_labels.insert(position, String::new());
        let spaced_host = spaced_labels.join(".");
        let address = format!("{spaced_host}/owner/{repository}");

        let parsed = parse_repository_address(&address);

        prop_assert_eq!(parsed, invalid_host(&spaced_host));
    }

    #[test]
    fn test_validate_host_property_keeps_every_dotted_host_verbatim(
        host in host(),
        owner in path_part(),
        repository in path_part(),
    ) {
        let address = format!("{host}/{owner}/{repository}");

        let parsed = parse_repository_address(&address);

        let host_prefix = format!("{host}/");
        let has_host = parsed.as_ref().is_ok_and(|canonical| {
            canonical.starts_with(&host_prefix)
        });
        prop_assert!(has_host);
    }

    #[test]
    fn test_is_host_label_property_any_label_position_is_checked(
        labels in vec(host_label(), 2..MAXIMUM_LABELS),
        bad_position in any::<prop::sample::Index>(),
        bad_character in "[_~!*+=,;]",
    ) {
        let mut tainted_labels = labels.clone();
        let position = bad_position.index(labels.len());
        tainted_labels[position].push_str(&bad_character);
        let tainted_host = tainted_labels.join(".");
        let address = format!("{tainted_host}/owner/app");

        let parsed = parse_repository_address(&address);

        prop_assert_eq!(parsed, invalid_host(&tainted_host));
    }

    #[test]
    fn test_is_host_label_property_trailing_dot_leaves_an_empty_label(
        host in host(),
        repository in path_part(),
    ) {
        let dotted_host = format!("{host}.");
        let address = format!("{dotted_host}/owner/{repository}");

        let parsed = parse_repository_address(&address);

        prop_assert_eq!(parsed, invalid_host(&dotted_host));
    }

    #[test]
    fn test_is_host_label_property_inner_hyphens_are_allowed(
        first in "[a-z0-9]{1,4}",
        last in "[a-z0-9]{1,4}",
        hyphen_count in 1..4_usize,
    ) {
        let label = format!("{first}{}{last}", "-".repeat(hyphen_count));
        let address = format!("{label}.example/owner/app");

        let parsed = parse_repository_address(&address);

        prop_assert_eq!(parsed, Ok(address));
    }

    #[test]
    fn test_is_host_character_property_any_ascii_letter_or_digit_is_a_label(
        character in ASCII_HOST_CHARACTERS,
    ) {
        let address = format!("a{character}b.example/owner/app");

        let parsed = parse_repository_address(&address);

        prop_assert_eq!(parsed, Ok(address.to_ascii_lowercase()));
    }

    #[test]
    fn test_is_host_character_property_refuses_every_other_character(
        character in any::<char>(),
    ) {
        prop_assume!(!is_host_character(character));
        prop_assume!(!is_structural(character));
        let tainted_host = format!("a{character}b.example");
        let address = format!("{tainted_host}/owner/app");

        let parsed = parse_repository_address(&address);

        prop_assert_eq!(parsed, invalid_host(&tainted_host));
    }

    #[test]
    fn test_is_host_character_property_refuses_non_ascii_letters(
        letter in "[à-ÿа-яα-ω]",
    ) {
        let tainted_host = format!("git{letter}hub.com");
        let address = format!("{tainted_host}/owner/app");

        let parsed = parse_repository_address(&address);

        prop_assert_eq!(parsed, invalid_host(&tainted_host));
    }

    #[test]
    fn test_validate_path_part_property_refuses_dot_parts(
        host in host(),
        reserved_index in 0..RESERVED_PATH_PARTS.len(),
        is_owner in any::<bool>(),
    ) {
        let reserved = RESERVED_PATH_PARTS[reserved_index];
        let address = if is_owner {
            format!("{host}/{reserved}/app")
        } else {
            format!("{host}/owner/{reserved}")
        };

        let parsed = parse_repository_address(&address);

        prop_assert_eq!(parsed, invalid_part(reserved));
    }

    #[test]
    fn test_validate_path_part_property_refuses_an_empty_owner(
        host in host(),
        repository in path_part(),
    ) {
        let address = format!("{host}//{repository}");

        prop_assert_eq!(parse_repository_address(&address), invalid_part(""));
    }

    #[test]
    fn test_validate_path_part_property_keeps_valid_parts_verbatim(
        host in host(),
        owner in path_part(),
        repository in path_part(),
    ) {
        let address = format!("https://{host}/{owner}/{repository}/");

        let parsed = parse_repository_address(&address);

        prop_assert_eq!(parsed, Ok(format!("{host}/{owner}/{repository}")));
    }

    #[test]
    fn test_is_path_character_property_any_allowed_character_is_a_name(
        character in ASCII_PATH_CHARACTERS,
    ) {
        let address = format!("github.com/{character}/{character}");

        prop_assert_eq!(parse_repository_address(&address), Ok(address));
    }

    #[test]
    fn test_is_path_character_property_refuses_every_other_character(
        character in any::<char>(),
        is_owner in any::<bool>(),
    ) {
        prop_assume!(!is_path_character(character));
        prop_assume!(!is_structural(character));
        let tainted_part = format!("a{character}b");
        let address = if is_owner {
            format!("github.com/{tainted_part}/app")
        } else {
            format!("github.com/owner/{tainted_part}")
        };

        let parsed = parse_repository_address(&address);

        prop_assert_eq!(parsed, invalid_part(&tainted_part));
    }

    #[test]
    fn test_is_path_character_property_dots_inside_names_are_allowed(
        dotted_name in DOTTED_NAME,
    ) {
        prop_assume!(!RESERVED_PATH_PARTS.contains(&dotted_name.as_str()));
        let address = format!("github.com/{dotted_name}/app");

        prop_assert_eq!(parse_repository_address(&address), Ok(address));
    }
}
