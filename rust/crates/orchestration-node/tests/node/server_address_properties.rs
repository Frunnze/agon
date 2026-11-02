use orchestration_node::server_address::{PEER_SCHEME_PREFIX, ServerAddress};
use proptest::prelude::*;

use crate::support::address_strategies::{
    direct_addresses_strategy, peer_address_strategy, server_address_strategy,
};

const INVALID_ADDRESS_START: &str = "the server address";
const FOREIGN_SCHEME_PATTERN: &str = "(ftp|ws|file|mailto)://[a-z]{1,12}";
const SHORT_KEY_PATTERN: &str = "peer://[0-9a-f]{2,62}";
const UNKNOWN_FIELD_PATTERN: &str = "[b-ce-qs-z][a-z]{0,8}";

proptest! {
    #[test]
    fn test_parse_property_a_rendered_address_parses_back_to_itself(
        address in server_address_strategy(),
    ) {
        let rendered = address.to_string();

        let parsed = ServerAddress::parse(&rendered);

        let parsed_text = parsed.map_err(|error| error.to_string());
        prop_assert_eq!(parsed_text, Ok(address));
    }

    #[test]
    fn test_parse_property_peer_addresses_use_their_own_scheme(
        peer_address in peer_address_strategy(),
    ) {
        let rendered = ServerAddress::Peer(peer_address).to_string();

        prop_assert!(rendered.starts_with(PEER_SCHEME_PREFIX), "{}", rendered);
        prop_assert!(!rendered.starts_with("http"), "{}", rendered);
    }

    #[test]
    fn test_with_direct_addresses_property_splitting_and_joining_round_trips(
        peer_address in peer_address_strategy(),
        extra_addresses in direct_addresses_strategy(),
    ) {
        let address = ServerAddress::Peer(peer_address.clone());

        let bare = address.without_direct_addresses();
        let joined =
            bare.clone().with_direct_addresses(address.direct_addresses());
        let extended = address.clone().with_direct_addresses(&extra_addresses);

        prop_assert!(bare.direct_addresses().is_empty());
        prop_assert_eq!(joined, address.clone());
        let mut expected = peer_address.direct_addresses.clone();
        expected.extend(extra_addresses);
        prop_assert_eq!(extended.direct_addresses(), expected.as_slice());
    }

    #[test]
    fn test_parse_property_foreign_schemes_give_a_defined_error(
        text in FOREIGN_SCHEME_PATTERN,
    ) {
        let parsed = ServerAddress::parse(&text);

        let problem = parsed.err().map(|error| error.to_string());
        let is_defined = problem
            .as_ref()
            .is_some_and(|text| text.starts_with(INVALID_ADDRESS_START));
        prop_assert!(is_defined, "{:?}", problem);
    }

    #[test]
    fn test_parse_property_a_short_peer_key_is_refused(
        text in SHORT_KEY_PATTERN,
    ) {
        prop_assert!(ServerAddress::parse(&text).is_err());
    }

    #[test]
    fn test_parse_property_unknown_peer_fields_are_refused(
        peer_address in peer_address_strategy(),
        field in UNKNOWN_FIELD_PATTERN,
    ) {
        let rendered = ServerAddress::Peer(peer_address).to_string();
        let separator = if rendered.contains('?') { '&' } else { '?' };
        let with_unknown = format!("{rendered}{separator}{field}=1");

        prop_assert!(ServerAddress::parse(&with_unknown).is_err());
    }

    #[test]
    fn test_parse_property_arbitrary_text_never_panics(
        text in "\\PC{0,120}",
    ) {
        let parsed = ServerAddress::parse(&text);

        if let Err(problem) = parsed {
            let problem_text = problem.to_string();
            prop_assert!(problem_text.starts_with(INVALID_ADDRESS_START));
        }
    }
}

#[test]
fn test_parse_property_a_web_address_loses_its_trailing_slash() {
    let parsed = ServerAddress::parse("https://server.example.org/");

    assert_eq!(
        parsed.map(|address| address.to_string()).ok(),
        Some("https://server.example.org".to_owned())
    );
}
