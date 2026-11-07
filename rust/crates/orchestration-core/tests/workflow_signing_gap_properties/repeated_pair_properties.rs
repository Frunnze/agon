use std::collections::BTreeSet;

use orchestration_core::workflow::AgentConnection;
use orchestration_core::workflow_graph::{WorkflowProblem, validate_workflow};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::routing_fixtures::{connect, routing_workflow};
use crate::signing_gap_support::{CONDITION_CHOICES, agent_count, name_agent};
use crate::workflow_strategies::agent_identifier;

const LARGEST_DRAWN_CONNECTION_COUNT: usize = 8;
const LOOP_OUTCOME: &str = "again";
const LARGEST_ROUND_LIMIT: u32 = 10;

type DrawnConnection = (u128, u128, usize);

fn forward_pair() -> impl Strategy<Value = (u128, u128, u128)> {
    agent_count().prop_flat_map(|agent_count| {
        (Just(agent_count), 0..agent_count, 0..agent_count)
            .prop_filter("a pair needs two steps", |(_, first, second)| {
                first != second
            })
            .prop_map(|(agent_count, first, second)| {
                (agent_count, first.min(second), first.max(second))
            })
    })
}

fn drawn_forward_connections()
-> impl Strategy<Value = (u128, Vec<DrawnConnection>)> {
    agent_count().prop_flat_map(|agent_count| {
        let drawn_connection =
            (0..agent_count, 0..agent_count, 0..CONDITION_CHOICES.len())
                .prop_filter("a forward connection", |(from, to, _)| {
                    from < to
                });
        (
            Just(agent_count),
            vec(drawn_connection, 0..=LARGEST_DRAWN_CONNECTION_COUNT),
        )
    })
}

fn build_drawn_connections(drawn: &[DrawnConnection]) -> Vec<AgentConnection> {
    let mut connections = Vec::new();
    for (from, to, condition_position) in drawn {
        let condition = CONDITION_CHOICES[*condition_position];
        connections.push(connect(*from, *to, condition, None));
    }
    connections
}

fn find_first_repeated_pair(
    connections: &[AgentConnection],
) -> Option<&AgentConnection> {
    let mut seen_pairs = BTreeSet::new();
    connections.iter().find(|connection| {
        !seen_pairs.insert((connection.from, connection.to))
    })
}

fn has_shared_outcome(connections: &[AgentConnection]) -> bool {
    let mut seen_outcomes = BTreeSet::new();
    for connection in connections {
        if let Some(condition) = &connection.condition
            && !seen_outcomes.insert((connection.from, condition.clone()))
        {
            return true;
        }
    }
    false
}

proptest! {
    #[test]
    fn test_validate_distinct_step_pairs_property_refuses_a_second_connection(
        (agent_count, from, to) in forward_pair(),
        first_choice in 0..CONDITION_CHOICES.len(),
        second_choice in 0..CONDITION_CHOICES.len(),
        is_copy_first in any::<bool>(),
    ) {
        let first_condition = CONDITION_CHOICES[first_choice];
        prop_assume!(
            first_choice != second_choice || first_condition.is_none()
        );
        let original =
            connect(from, to, CONDITION_CHOICES[first_choice], None);
        let copy = connect(from, to, CONDITION_CHOICES[second_choice], None);
        let connections = if is_copy_first {
            vec![copy, original]
        } else {
            vec![original, copy]
        };
        let workflow = routing_workflow(agent_count, connections);
        let from_name = name_agent(&workflow, agent_identifier(from));
        let to_name = name_agent(&workflow, agent_identifier(to));

        let verdict = validate_workflow(&workflow);

        let message = verdict
            .clone()
            .err()
            .map(|problem| problem.to_string())
            .unwrap_or_default();
        let expected = WorkflowProblem::RepeatedConnection {
            from: from_name.clone(),
            to: to_name.clone(),
        };
        prop_assert_eq!(verdict, Err(expected));
        prop_assert!(message.contains(&from_name));
        prop_assert!(message.contains(&to_name));
    }

    #[test]
    fn test_validate_distinct_step_pairs_property_keeps_the_way_back(
        (agent_count, from, to) in forward_pair(),
        forward_choice in 0..CONDITION_CHOICES.len(),
        round_limit in 1..=LARGEST_ROUND_LIMIT,
    ) {
        let forward =
            connect(from, to, CONDITION_CHOICES[forward_choice], None);
        let way_back =
            connect(to, from, Some(LOOP_OUTCOME), Some(round_limit));
        let workflow = routing_workflow(agent_count, vec![forward, way_back]);

        prop_assert_eq!(validate_workflow(&workflow), Ok(()));
    }

    #[test]
    fn test_validate_distinct_step_pairs_property_matches_a_pair_model(
        (agent_count, drawn) in drawn_forward_connections(),
    ) {
        let connections = build_drawn_connections(&drawn);
        let workflow = routing_workflow(agent_count, connections);

        let verdict = validate_workflow(&workflow);

        if has_shared_outcome(&workflow.connections) {
            let is_shared_outcome = matches!(
                verdict,
                Err(WorkflowProblem::DuplicateCondition { .. })
            );
            prop_assert!(is_shared_outcome, "{:?}", verdict);
        } else {
            let repeated = find_first_repeated_pair(&workflow.connections);
            let expected = repeated.map_or(Ok(()), |repeated_connection| {
                Err(WorkflowProblem::RepeatedConnection {
                    from: name_agent(&workflow, repeated_connection.from),
                    to: name_agent(&workflow, repeated_connection.to),
                })
            });
            prop_assert_eq!(verdict, expected);
        }
    }
}
