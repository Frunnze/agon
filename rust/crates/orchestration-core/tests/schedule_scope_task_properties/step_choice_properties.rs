use orchestration_core::step_outcomes::list_step_choices;
use orchestration_core::workflow::AgentConnection;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::routing_fixtures::{connect, routing_workflow};
use crate::workflow_strategies::agent_identifier;

const AGENT_COUNT: u128 = 4;
const UNKNOWN_AGENT_NUMBER: u128 = 99;
const MOST_CONNECTIONS: usize = 8;

fn connection() -> impl Strategy<Value = AgentConnection> {
    (
        0..AGENT_COUNT,
        0..AGENT_COUNT,
        proptest::option::of("[a-z]{1,6}"),
    )
        .prop_map(|(from, to, condition)| {
            connect(from, to, condition.as_deref(), None)
        })
}

proptest! {
    #[test]
    fn test_list_step_choices_property_an_unknown_step_has_no_choices(
        connections in vec(connection(), 0..MOST_CONNECTIONS),
    ) {
        let workflow = routing_workflow(AGENT_COUNT, connections);
        let unknown = agent_identifier(UNKNOWN_AGENT_NUMBER);

        prop_assert!(list_step_choices(&workflow, unknown).is_empty());
    }

    #[test]
    fn test_list_step_choices_property_plain_connections_add_no_choices(
        connections in vec(connection(), 0..MOST_CONNECTIONS),
        plain_targets in vec(0..AGENT_COUNT, 0..MOST_CONNECTIONS),
        source in 0..AGENT_COUNT,
    ) {
        let mut with_plain = connections.clone();
        for target in plain_targets {
            with_plain.push(connect(source, target, None, None));
        }
        let workflow = routing_workflow(AGENT_COUNT, connections);
        let widened = routing_workflow(AGENT_COUNT, with_plain);
        let source_id = agent_identifier(source);

        prop_assert_eq!(
            list_step_choices(&widened, source_id),
            list_step_choices(&workflow, source_id)
        );
    }
}
