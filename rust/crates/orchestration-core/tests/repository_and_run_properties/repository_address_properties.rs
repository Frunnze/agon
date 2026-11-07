use orchestration_core::local_folders::{
    LocalFolderProblem, parse_local_address,
};
use orchestration_core::repository_address::{
    AddressProblem, parse_repository_address,
};
use proptest::prelude::*;

use crate::address_strategies::{canonical_address, host, path_part};

const SURROUNDING_WHITESPACE: &str = "[ \t\r\n\u{a0}\u{3000}]{0,4}";
const OTHER_SCHEME: &str = "[a-z][a-z0-9+.-]{0,8}";
const SUPPORTED_SCHEME: &str = "https";
const DEVICE_TEXT: &str = "[a-z0-9-]{1,12}";
const RELATIVE_FOLDER: &str = "[a-z][a-z0-9_-]{0,10}";

fn problems_carrying(text: &str) -> Vec<AddressProblem> {
    vec![
        AddressProblem::UnsupportedScheme {
            scheme: text.to_owned(),
        },
        AddressProblem::InvalidHost {
            host: text.to_owned(),
        },
        AddressProblem::InvalidPathPart {
            part: text.to_owned(),
        },
    ]
}

proptest! {
    #[test]
    fn test_parse_repository_address_property_ignores_surrounding_whitespace(
        address in canonical_address(),
        leading_space in SURROUNDING_WHITESPACE,
        trailing_space in SURROUNDING_WHITESPACE,
    ) {
        let padded_address =
            format!("{leading_space}{address}{trailing_space}");

        let parsed = parse_repository_address(&padded_address);

        prop_assert_eq!(parsed, Ok(address));
    }

    #[test]
    fn test_parse_repository_address_property_reads_back_its_clone_url(
        address in canonical_address(),
    ) {
        let clone_url = format!("https://{address}.git");

        let parsed = parse_repository_address(&clone_url);

        prop_assert_eq!(parsed, Ok(address));
    }

    #[test]
    fn test_parse_repository_address_property_lowers_only_the_host(
        host in host(),
        owner in path_part(),
        repository in path_part(),
    ) {
        let shouted_host = host.to_ascii_uppercase();
        let address = format!("{shouted_host}/{owner}/{repository}");

        let parsed = parse_repository_address(&address);

        prop_assert_eq!(parsed, Ok(format!("{host}/{owner}/{repository}")));
    }

    #[test]
    fn test_remove_address_prefix_property_https_and_git_at_forms_agree(
        host in host(),
        owner in path_part(),
        repository in path_part(),
    ) {
        let bare = format!("{host}/{owner}/{repository}");
        let https_form = format!("https://{host}/{owner}/{repository}");
        let git_at_form = format!("git@{host}:{owner}/{repository}");

        let expected = parse_repository_address(&bare);

        prop_assert_eq!(&expected, &Ok(bare.clone()));
        let https_parsed = parse_repository_address(&https_form);
        let git_at_parsed = parse_repository_address(&git_at_form);
        prop_assert_eq!(https_parsed, expected.clone());
        prop_assert_eq!(git_at_parsed, expected);
    }

    #[test]
    fn test_remove_address_prefix_property_git_at_needs_a_colon(
        address in canonical_address(),
    ) {
        let without_colon = format!("git@{address}");

        let parsed = parse_repository_address(&without_colon);

        prop_assert_eq!(parsed, Err(AddressProblem::MissingColon));
    }

    #[test]
    fn test_remove_address_prefix_property_names_any_other_scheme(
        scheme in OTHER_SCHEME,
        address in canonical_address(),
    ) {
        prop_assume!(scheme != SUPPORTED_SCHEME);
        let with_scheme = format!("{scheme}://{address}");

        let parsed = parse_repository_address(&with_scheme);

        let expected = AddressProblem::UnsupportedScheme { scheme };
        prop_assert_eq!(parsed, Err(expected));
    }

    #[test]
    fn test_address_problem_fmt_property_names_the_refused_text(
        refused_text in any::<String>(),
        part_count in any::<usize>(),
    ) {
        for problem in problems_carrying(&refused_text) {
            prop_assert!(problem.to_string().contains(&refused_text));
        }
        let wrong_count = AddressProblem::WrongPartCount { part_count };

        let count_text = part_count.to_string();
        prop_assert!(wrong_count.to_string().contains(&count_text));
    }

    #[test]
    fn test_address_problem_fmt_property_tells_each_problem_apart(
        refused_text in any::<String>(),
    ) {
        let mut messages: Vec<String> = Vec::new();
        for problem in problems_carrying(&refused_text) {
            messages.push(problem.to_string());
        }
        messages.push(AddressProblem::Empty.to_string());
        messages.push(AddressProblem::MissingColon.to_string());

        for (index, message) in messages.iter().enumerate() {
            let repeats = messages[index + 1..].contains(message);
            prop_assert!(!repeats, "{} repeats", message);
        }
    }

    #[test]
    fn test_address_problem_fmt_property_local_problems_read_unchanged(
        device_text in DEVICE_TEXT,
        relative_folder in RELATIVE_FOLDER,
    ) {
        let address = format!("local:{device_text}:{relative_folder}");
        let local_problem = parse_local_address(&address).err();

        let parsed = parse_repository_address(&address);

        let expected = LocalFolderProblem::RelativePath(relative_folder);
        prop_assert_eq!(&local_problem, &Some(expected.clone()));
        let problem = parsed.err();
        let message = problem.as_ref().map(ToString::to_string);
        prop_assert_eq!(message, Some(expected.to_string()));
        prop_assert_eq!(problem, Some(AddressProblem::LocalFolder(expected)));
    }
}
