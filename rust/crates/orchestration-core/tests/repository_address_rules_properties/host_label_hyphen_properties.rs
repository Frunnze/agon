use orchestration_core::repository_address::{
    AddressProblem, parse_repository_address,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::address_strategies::{host_label, path_part};

const MAXIMUM_LABELS: usize = 4;
const MAXIMUM_EDGE_HYPHENS: usize = 3;
const HYPHEN: &str = "-";
const ANY_LABEL_TEXT: &str = "[A-Za-z0-9-]{1,8}";

fn invalid_host(host: &str) -> Result<String, AddressProblem> {
    Err(AddressProblem::InvalidHost {
        host: host.to_owned(),
    })
}

fn follows_dns_label_rule(label: &str) -> bool {
    let starts_with_alphanumeric =
        label.starts_with(|character: char| character.is_ascii_alphanumeric());
    let ends_with_alphanumeric =
        label.ends_with(|character: char| character.is_ascii_alphanumeric());
    let has_only_label_characters = label.chars().all(|character| {
        character.is_ascii_alphanumeric() || character == '-'
    });
    starts_with_alphanumeric
        && ends_with_alphanumeric
        && has_only_label_characters
}

proptest! {
    #[test]
    fn test_is_host_label_property_refuses_a_leading_hyphen(
        labels in vec(host_label(), 2..MAXIMUM_LABELS),
        tainted_position in any::<prop::sample::Index>(),
        hyphen_count in 1..=MAXIMUM_EDGE_HYPHENS,
        owner in path_part(),
        repository in path_part(),
    ) {
        let position = tainted_position.index(labels.len());
        let hyphens = HYPHEN.repeat(hyphen_count);
        let mut tainted_labels = labels.clone();
        tainted_labels[position] = format!("{hyphens}{}", labels[position]);
        let tainted_host = tainted_labels.join(".");
        let address = format!("{tainted_host}/{owner}/{repository}");

        let parsed = parse_repository_address(&address);

        prop_assert_eq!(parsed, invalid_host(&tainted_host));
    }

    #[test]
    fn test_is_host_label_property_refuses_a_trailing_hyphen(
        labels in vec(host_label(), 2..MAXIMUM_LABELS),
        tainted_position in any::<prop::sample::Index>(),
        hyphen_count in 1..=MAXIMUM_EDGE_HYPHENS,
        owner in path_part(),
        repository in path_part(),
    ) {
        let position = tainted_position.index(labels.len());
        let hyphens = HYPHEN.repeat(hyphen_count);
        let mut tainted_labels = labels.clone();
        tainted_labels[position] = format!("{}{hyphens}", labels[position]);
        let tainted_host = tainted_labels.join(".");
        let address = format!("{tainted_host}/{owner}/{repository}");

        let parsed = parse_repository_address(&address);

        prop_assert_eq!(parsed, invalid_host(&tainted_host));
    }

    #[test]
    fn test_is_host_label_property_refuses_edge_hyphens_in_every_form(
        label in host_label(),
        is_leading in any::<bool>(),
        owner in path_part(),
        repository in path_part(),
    ) {
        let tainted_label = if is_leading {
            format!("{HYPHEN}{label}")
        } else {
            format!("{label}{HYPHEN}")
        };
        let tainted_host = format!("{tainted_label}.example");
        let forms = [
            format!("{tainted_host}/{owner}/{repository}"),
            format!("https://{tainted_host}/{owner}/{repository}.git"),
            format!("HTTPS://{tainted_host}/{owner}/{repository}/"),
            format!("git@{tainted_host}:{owner}/{repository}.git"),
        ];

        for form in forms {
            let parsed = parse_repository_address(&form);
            prop_assert_eq!(parsed, invalid_host(&tainted_host));
        }
    }

    #[test]
    fn test_is_host_label_property_refuses_a_label_of_only_hyphens(
        hyphen_count in 1..=MAXIMUM_EDGE_HYPHENS,
        top_level in "[a-z]{2,6}",
    ) {
        let hyphens = HYPHEN.repeat(hyphen_count);
        let tainted_host = format!("{hyphens}.{top_level}");
        let address = format!("{tainted_host}/owner/app");

        let parsed = parse_repository_address(&address);

        prop_assert_eq!(parsed, invalid_host(&tainted_host));
    }

    #[test]
    fn test_is_host_label_property_matches_the_dns_label_rule(
        label in ANY_LABEL_TEXT,
        is_top_level in any::<bool>(),
    ) {
        let host = if is_top_level {
            format!("example.{label}")
        } else {
            format!("{label}.example")
        };
        let address = format!("{host}/owner/app");

        let is_accepted = parse_repository_address(&address).is_ok();

        prop_assert_eq!(is_accepted, follows_dns_label_rule(&label));
    }
}
