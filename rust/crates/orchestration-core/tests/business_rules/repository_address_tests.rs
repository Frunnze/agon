use orchestration_core::repository_address::{
    AddressProblem, parse_repository_address,
};
use proptest::collection::vec;
use proptest::prelude::*;

const MAXIMUM_HOST_LABELS: usize = 3;
const CANONICAL_SEPARATOR_COUNT: usize = 2;
const MAXIMUM_GENERATED_PARTS: usize = 6;
const MAXIMUM_GIT_SUFFIXES: usize = 4;

fn host() -> impl Strategy<Value = String> {
    (
        vec("[a-z0-9]([a-z0-9-]{0,7}[a-z0-9])?", 1..MAXIMUM_HOST_LABELS),
        "[a-z]{2,6}",
    )
        .prop_map(|(labels, top_level)| {
            format!("{}.{top_level}", labels.join("."))
        })
}

fn path_part() -> impl Strategy<Value = String> {
    "[A-Za-z0-9][A-Za-z0-9_-]{0,12}"
}

fn canonical_address() -> impl Strategy<Value = String> {
    (host(), path_part(), path_part()).prop_map(|(host, owner, repository)| {
        format!("{host}/{owner}/{repository}")
    })
}

#[test]
fn test_parse_repository_address_accepts_the_three_documented_forms() {
    let expected = Ok("github.com/acme/app".to_owned());

    assert_eq!(
        parse_repository_address("https://github.com/acme/app.git"),
        expected
    );
    assert_eq!(parse_repository_address("github.com/acme/app"), expected);
    assert_eq!(
        parse_repository_address("git@github.com:acme/app.git"),
        expected
    );
}

proptest! {
    #[test]
    fn test_parse_repository_address_property_all_forms_agree(
        host in host(),
        owner in path_part(),
        repository in path_part(),
    ) {
        let expected = Ok(format!("{host}/{owner}/{repository}"));
        let forms = [
            format!("https://{host}/{owner}/{repository}.git"),
            format!("https://{host}/{owner}/{repository}/"),
            format!("{host}/{owner}/{repository}"),
            format!("  {host}/{owner}/{repository}.git  "),
            format!("git@{host}:{owner}/{repository}.git"),
            format!("git@{host}:{owner}/{repository}"),
        ];

        for form in forms {
            prop_assert_eq!(parse_repository_address(&form), expected.clone());
        }
    }

    #[test]
    fn test_parse_repository_address_property_canonical_form_is_stable(
        address in canonical_address(),
    ) {
        prop_assert_eq!(parse_repository_address(&address), Ok(address));
    }

    #[test]
    fn test_parse_repository_address_property_parsing_twice_changes_nothing(
        address in canonical_address(),
        suffix_count in 0..MAXIMUM_GIT_SUFFIXES,
    ) {
        let suffixed = format!("{address}{}", ".git".repeat(suffix_count));

        let parsed_once = parse_repository_address(&suffixed);
        let parsed_twice = parsed_once
            .clone()
            .and_then(|canonical| parse_repository_address(&canonical));

        prop_assert_eq!(parsed_once.clone(), Ok(address));
        prop_assert_eq!(parsed_twice, parsed_once);
    }

    #[test]
    fn test_parse_repository_address_property_rejects_other_schemes(
        scheme in "(http|ssh|ftp|file)",
        address in canonical_address(),
    ) {
        let with_scheme = format!("{scheme}://{address}");

        prop_assert_eq!(
            parse_repository_address(&with_scheme),
            Err(AddressProblem::UnsupportedScheme { scheme })
        );
    }

    #[test]
    fn test_parse_repository_address_property_needs_exactly_three_parts(
        host in host(),
        parts in vec(path_part(), 0..MAXIMUM_GENERATED_PARTS),
    ) {
        let address = format!("{host}/{}", parts.join("/"));
        let expected_part_count = parts.len() + 1;

        let parsed = parse_repository_address(&address);

        if parts.len() == CANONICAL_SEPARATOR_COUNT {
            prop_assert!(parsed.is_ok());
        } else {
            prop_assert_eq!(
                parsed,
                Err(AddressProblem::WrongPartCount {
                    part_count: expected_part_count,
                })
            );
        }
    }

    #[test]
    fn test_parse_repository_address_fuzz_results_are_canonical(
        address in any::<String>(),
    ) {
        let parsed = parse_repository_address(&address);

        if let Ok(canonical) = parsed {
            let separator_count = canonical.matches('/').count();
            prop_assert_eq!(separator_count, CANONICAL_SEPARATOR_COUNT);
            prop_assert_eq!(
                parse_repository_address(&canonical),
                Ok(canonical.clone())
            );
        }
    }

    #[test]
    fn test_parse_repository_address_fuzz_shaped_input_is_idempotent(
        address in "(https://|git@)?[a-z.:@/-]{0,30}(\\.git)?/?",
    ) {
        let parsed = parse_repository_address(&address);

        if let Ok(canonical) = parsed {
            prop_assert_eq!(
                parse_repository_address(&canonical),
                Ok(canonical.clone())
            );
        }
    }
}

#[test]
fn test_parse_repository_address_rejects_blank_text() {
    assert_eq!(parse_repository_address("   "), Err(AddressProblem::Empty));
}
