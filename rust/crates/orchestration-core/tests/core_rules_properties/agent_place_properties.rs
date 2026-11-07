use orchestration_core::agent_place::{
    AgentPlace, can_take_place, find_sandbox_place,
};
use orchestration_core::device::SandboxKind;
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::Value;

use crate::entity_strategies::agent_place;

const MAXIMUM_OFFERS: usize = 5;

fn sandbox_kind() -> impl Strategy<Value = SandboxKind> {
    prop_oneof![
        Just(SandboxKind::Container),
        Just(SandboxKind::MicroVirtualMachine),
        Just(SandboxKind::LocalProcess),
    ]
}

fn encode(encodable: &impl serde::Serialize) -> Result<Value, TestCaseError> {
    serde_json::to_value(encodable)
        .map_err(|error| TestCaseError::fail(error.to_string()))
}

proptest! {
    #[test]
    fn test_can_take_place_property_ignores_offer_order_and_repeats(
        offers in vec(agent_place(), 0..MAXIMUM_OFFERS),
        wanted in proptest::option::of(agent_place()),
    ) {
        let mut reordered_offers = offers.clone();
        reordered_offers.reverse();
        reordered_offers.extend(offers.iter().copied());

        let original_answer = can_take_place(&offers, wanted);
        let reordered_answer = can_take_place(&reordered_offers, wanted);

        prop_assert_eq!(original_answer, reordered_answer);
    }

    #[test]
    fn test_can_take_place_property_one_more_offer_never_refuses(
        offers in vec(agent_place(), 0..MAXIMUM_OFFERS),
        extra_offer in agent_place(),
        wanted in proptest::option::of(agent_place()),
    ) {
        let mut wider_offers = offers.clone();
        wider_offers.push(extra_offer);

        if can_take_place(&offers, wanted) {
            prop_assert!(can_take_place(&wider_offers, wanted));
        }
    }

    #[test]
    fn test_find_sandbox_place_property_shares_the_sandbox_wire_name(
        kind in sandbox_kind(),
    ) {
        let Some(place) = find_sandbox_place(kind) else {
            return Ok(());
        };

        prop_assert_eq!(encode(&place)?, encode(&kind)?);
    }

    #[test]
    fn test_find_sandbox_place_property_finds_a_place_its_offer_takes(
        kind in sandbox_kind(),
    ) {
        let Some(place) = find_sandbox_place(kind) else {
            return Ok(());
        };

        prop_assert!(can_take_place(&[place], Some(place)));
        prop_assert!(can_take_place(&[place], None));
    }

    #[test]
    fn test_agent_place_serde_property_round_trips_as_snake_case(
        place in agent_place(),
    ) {
        let encoded = encode(&place)?;
        let decoded: AgentPlace = serde_json::from_value(encoded.clone())
            .map_err(|error| TestCaseError::fail(error.to_string()))?;

        let Value::String(wire_name) = encoded else {
            return Err(TestCaseError::fail("a place is written as text"));
        };
        prop_assert_eq!(decoded, place);
        prop_assert!(
            wire_name
                .chars()
                .all(|letter| letter.is_ascii_lowercase() || letter == '_')
        );
    }
}
