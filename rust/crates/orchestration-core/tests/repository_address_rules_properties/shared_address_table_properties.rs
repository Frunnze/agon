use orchestration_core::repository_address::parse_repository_address;
use proptest::prelude::*;
use serde::Deserialize;

const SHARED_ADDRESS_CASES: &str =
    include_str!("../fixtures/repository_address_cases.json");
const SURROUNDING_WHITESPACE: &str = "[ \t\r\n]{0,3}";

#[derive(Debug, Deserialize)]
struct SharedAddressCase {
    address: String,
    canonical: Option<String>,
}

fn read_shared_cases() -> Result<Vec<SharedAddressCase>, serde_json::Error> {
    serde_json::from_str(SHARED_ADDRESS_CASES)
}

#[test]
fn test_parse_repository_address_property_agrees_with_the_shared_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_cases()? {
        let parsed = parse_repository_address(&case.address).ok();

        assert_eq!(parsed, case.canonical, "{:?}", case.address);
    }
    Ok(())
}

#[test]
fn test_parse_repository_address_property_shared_answers_are_fixed_points()
-> Result<(), serde_json::Error> {
    for case in read_shared_cases()? {
        let Some(canonical) = case.canonical else {
            continue;
        };
        let clone_url = format!("https://{canonical}.git");

        let reparsed = parse_repository_address(&canonical);
        let read_back = parse_repository_address(&clone_url);

        assert_eq!(reparsed.as_ref(), Ok(&canonical));
        assert_eq!(read_back, Ok(canonical));
    }
    Ok(())
}

proptest! {
    #[test]
    fn test_parse_repository_address_property_shared_table_ignores_padding(
        case_position in any::<prop::sample::Index>(),
        leading_space in SURROUNDING_WHITESPACE,
        trailing_space in SURROUNDING_WHITESPACE,
    ) {
        let cases = read_shared_cases()?;
        let case = &cases[case_position.index(cases.len())];
        let address = &case.address;
        let padded = format!("{leading_space}{address}{trailing_space}");

        let parsed = parse_repository_address(&padded).ok();

        prop_assert_eq!(parsed, case.canonical.clone());
    }
}
