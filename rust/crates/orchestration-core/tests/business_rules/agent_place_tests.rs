use orchestration_core::agent_place::{
    AgentPlace, can_take_place, find_sandbox_place,
};
use orchestration_core::device::SandboxKind;
use orchestration_core::task::Task;
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::Value;

use crate::entity_strategies::{agent_place, example_task};

const MAXIMUM_OFFERS: usize = 4;
const PLACE_FIELD: &str = "agent_place";
const ALL_SANDBOX_KINDS: [SandboxKind; 3] = [
    SandboxKind::Container,
    SandboxKind::MicroVirtualMachine,
    SandboxKind::LocalProcess,
];

fn sandbox_kind() -> impl Strategy<Value = SandboxKind> {
    proptest::sample::select(ALL_SANDBOX_KINDS.to_vec())
}

fn fail_with(error: &serde_json::Error) -> TestCaseError {
    TestCaseError::fail(error.to_string())
}

proptest! {
    #[test]
    fn test_can_take_place_property_a_named_place_needs_that_offer(
        offers in vec(agent_place(), 0..MAXIMUM_OFFERS),
        wanted in agent_place(),
    ) {
        let can_take = can_take_place(&offers, Some(wanted));

        prop_assert_eq!(can_take, offers.contains(&wanted));
    }

    #[test]
    fn test_can_take_place_property_no_wanted_place_takes_any_offer(
        offers in vec(agent_place(), 0..MAXIMUM_OFFERS),
    ) {
        let can_take = can_take_place(&offers, None);

        prop_assert_eq!(can_take, !offers.is_empty());
    }

    #[test]
    fn test_find_sandbox_place_property_kinds_never_share_a_place(
        first in sandbox_kind(),
        second in sandbox_kind(),
    ) {
        let first_place = find_sandbox_place(first);
        let second_place = find_sandbox_place(second);

        if first != second && first_place.is_some() {
            prop_assert_ne!(first_place, second_place);
        }
    }

    #[test]
    fn test_find_sandbox_place_property_every_place_has_a_sandbox_kind(
        wanted in agent_place(),
    ) {
        let places: Vec<Option<AgentPlace>> = ALL_SANDBOX_KINDS
            .into_iter()
            .map(find_sandbox_place)
            .collect();

        prop_assert!(places.contains(&Some(wanted)));
    }

    #[test]
    fn test_task_property_the_agent_place_round_trips(
        wanted in proptest::option::of(agent_place()),
    ) {
        let task = Task {
            agent_place: wanted,
            ..example_task()
        };

        let encoded = serde_json::to_value(&task)
            .map_err(|error| fail_with(&error))?;
        let decoded: Task = serde_json::from_value(encoded)
            .map_err(|error| fail_with(&error))?;

        prop_assert_eq!(decoded, task);
    }

    #[test]
    fn test_task_property_tasks_saved_before_places_run_on_the_computer(
        wanted in proptest::option::of(agent_place()),
    ) {
        let task = Task {
            agent_place: wanted,
            ..example_task()
        };
        let mut encoded = serde_json::to_value(&task)
            .map_err(|error| fail_with(&error))?;
        if let Value::Object(fields) = &mut encoded {
            fields.remove(PLACE_FIELD);
        }

        let decoded: Task = serde_json::from_value(encoded)
            .map_err(|error| fail_with(&error))?;

        prop_assert_eq!(decoded.agent_place, Some(AgentPlace::LocalProcess));
    }
}
