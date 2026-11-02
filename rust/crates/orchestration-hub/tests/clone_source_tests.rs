use orchestration_core::repository_address::parse_repository_address;
use orchestration_hub::clone_source::{
    ADDRESS_PLACEHOLDER, CloneSource, CloneSourceProblem,
};
use proptest::prelude::*;

fn is_canonical(address: &str) -> bool {
    parse_repository_address(address).as_deref() == Ok(address)
}

fn any_canonical_address() -> impl Strategy<Value = String> {
    "[a-z][a-z0-9-]{0,7}\\.[a-z]{2,4}/[a-zA-Z0-9_-]{1,10}/[a-zA-Z0-9_.-]{1,12}"
        .prop_filter("the address is canonical", |address| {
            is_canonical(address)
        })
}

fn any_template_part() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9:/._~-]{0,24}"
}

fn any_hostile_address() -> impl Strategy<Value = String> {
    let hostile = prop_oneof![
        "(\\.\\./){1,4}[a-z]{0,6}",
        "/[a-z/.]{1,20}",
        "https://[a-z]{1,8}\\.com/[a-z]{1,8}/[a-z]{1,8}",
        "git@[a-z]{1,8}\\.com:[a-z]{1,8}/[a-z]{1,8}",
        "[a-z]{1,8}\\.com/[a-z]{1,8}/[a-z]{1,8}[ ;&|$`\\n@?#]{1,3}",
        "-[a-z-]{1,12}",
        "[a-z]{1,8}\\.com/\\.\\./[a-z]{1,8}",
        "[a-z]{1,8}\\.com/[a-z]{1,8}/[a-z]{1,8}/[a-z]{1,8}",
        any::<String>(),
    ];
    hostile.prop_filter("the address is not canonical", |address| {
        !is_canonical(address)
    })
}

#[test]
fn the_standard_source_clones_over_https() {
    let clone_url = CloneSource::standard().clone_url("github.com/acme/app");

    assert_eq!(clone_url, Ok("https://github.com/acme/app.git".to_owned()));
}

proptest! {
    #[test]
    fn test_clone_url_property_is_built_only_from_template_and_address(
        prefix in any_template_part(),
        suffix in any_template_part(),
        address in any_canonical_address(),
    ) {
        let template = format!("{prefix}{ADDRESS_PLACEHOLDER}{suffix}");
        let source = CloneSource::from_template(&template);
        let Ok(source) = source else {
            return Err(TestCaseError::fail(format!("{source:?}")));
        };

        let clone_url = source.clone_url(&address);

        prop_assert_eq!(clone_url, Ok(format!("{prefix}{address}{suffix}")));
    }

    #[test]
    fn test_clone_url_property_hostile_addresses_never_escape(
        prefix in any_template_part(),
        suffix in any_template_part(),
        address in any_hostile_address(),
    ) {
        let template = format!("{prefix}{ADDRESS_PLACEHOLDER}{suffix}");
        let source = CloneSource::from_template(&template);
        let Ok(source) = source else {
            return Err(TestCaseError::fail(format!("{source:?}")));
        };

        let clone_url = source.clone_url(&address);

        let expected = CloneSourceProblem::NonCanonicalAddress(address);
        prop_assert_eq!(clone_url, Err(expected));
    }

    #[test]
    fn test_from_template_property_needs_exactly_one_placeholder(
        parts in proptest::collection::vec(any_template_part(), 1..4),
        placeholder_count in prop_oneof![Just(0_usize), 2_usize..4],
    ) {
        let mut template = parts.join("");
        for _ in 0..placeholder_count {
            template.push_str(ADDRESS_PLACEHOLDER);
        }

        let source = CloneSource::from_template(&template);

        let expected = CloneSourceProblem::InvalidTemplate(template);
        prop_assert_eq!(source, Err(expected));
    }

    #[test]
    fn test_from_template_property_rejects_whitespace_and_control_text(
        prefix in any_template_part(),
        unsafe_text in "[ \\t\\n\\r\\x00-\\x1f]{1,3}",
    ) {
        let template = format!("{prefix}{unsafe_text}{ADDRESS_PLACEHOLDER}");

        let source = CloneSource::from_template(&template);

        let expected = CloneSourceProblem::InvalidTemplate(template);
        prop_assert_eq!(source, Err(expected));
    }
}
