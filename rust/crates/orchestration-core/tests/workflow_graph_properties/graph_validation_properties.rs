use orchestration_core::workflow::{AgentConnection, StepKind, WorkflowAgent};
use orchestration_core::workflow_graph::{WorkflowProblem, validate_workflow};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::routing_fixtures::{connect, routing_agent, routing_workflow};
use crate::workflow_strategies::{agent_identifier, workflow_from_parts};

const LARGEST_AGENT_COUNT: u128 = 6;
const LARGEST_CONNECTION_COUNT: usize = 10;
const UNKNOWN_NUMBER: u128 = 999;
const BACK_OUTCOME: &str = "back again";
const LOOP_ROUNDS: u32 = 3;

type DrawnEdges = Vec<(u128, u128)>;

fn drawn_edges(agent_count: u128) -> impl Strategy<Value = DrawnEdges> {
    vec(
        (0..agent_count, 0..agent_count),
        0..=LARGEST_CONNECTION_COUNT,
    )
    .prop_map(|pairs| {
        pairs.into_iter().filter(|(from, to)| from != to).collect()
    })
}

fn graph() -> impl Strategy<Value = (u128, DrawnEdges)> {
    (1..=LARGEST_AGENT_COUNT).prop_flat_map(|agent_count| {
        (Just(agent_count), drawn_edges(agent_count))
    })
}

fn has_cycle_by_depth_search(agent_count: u128, edges: &DrawnEdges) -> bool {
    let mut is_finished =
        vec![false; usize::try_from(agent_count).unwrap_or(0)];
    let mut is_on_path = is_finished.clone();
    let mut has_cycle = false;
    for start in 0..is_finished.len() {
        visit(
            start,
            edges,
            &mut is_on_path,
            &mut is_finished,
            &mut has_cycle,
        );
    }
    has_cycle
}

fn visit(
    step: usize,
    edges: &DrawnEdges,
    is_on_path: &mut [bool],
    is_finished: &mut [bool],
    has_cycle: &mut bool,
) {
    if is_finished[step] {
        return;
    }
    if is_on_path[step] {
        *has_cycle = true;
        return;
    }
    is_on_path[step] = true;
    for (from, to) in edges {
        let from_index = usize::try_from(*from).unwrap_or(0);
        if from_index == step {
            let to_index = usize::try_from(*to).unwrap_or(0);
            visit(to_index, edges, is_on_path, is_finished, has_cycle);
        }
    }
    is_on_path[step] = false;
    is_finished[step] = true;
}

fn outcome_for(position: usize) -> String {
    format!("outcome {position}")
}

fn agent_named(number: u128, name: &str) -> WorkflowAgent {
    WorkflowAgent {
        name: name.to_owned(),
        ..routing_agent(number, StepKind::Agent)
    }
}

proptest! {
    #[test]
    fn test_validate_unique_agents_property_a_repeated_id_is_named(
        agent_count in 1..=LARGEST_AGENT_COUNT,
        repeated in 0..LARGEST_AGENT_COUNT,
    ) {
        let repeated = repeated % agent_count;
        let mut agents = routing_workflow(agent_count, Vec::new()).agents;
        agents.push(agent_named(repeated, "a copy with its own name"));

        let workflow = workflow_from_parts(agents, Vec::new());
        let verdict = validate_workflow(&workflow);

        prop_assert_eq!(
            verdict,
            Err(WorkflowProblem::DuplicateAgentId {
                agent_id: agent_identifier(repeated),
            })
        );
    }

    #[test]
    fn test_validate_unique_agents_property_the_first_repeated_name_is_named(
        names in vec("[a-c]{1,2}", 2..=6),
    ) {
        let mut agents = Vec::new();
        for (number, name) in (0_u128..).zip(&names) {
            agents.push(agent_named(number, name));
        }

        let workflow = workflow_from_parts(agents, Vec::new());
        let verdict = validate_workflow(&workflow);

        let mut seen: Vec<&String> = Vec::new();
        let first_repeat = names.iter().find(|name| {
            let is_repeat = seen.contains(name);
            seen.push(name);
            is_repeat
        });
        let expected = first_repeat.map_or(Ok(()), |name| {
            Err(WorkflowProblem::DuplicateAgentName { name: name.clone() })
        });
        prop_assert_eq!(verdict, expected);
    }

    #[test]
    fn test_validate_unique_agents_property_a_full_copy_is_a_repeated_id(
        agent_count in 1..=LARGEST_AGENT_COUNT,
        repeated in 0..LARGEST_AGENT_COUNT,
    ) {
        let repeated = repeated % agent_count;
        let mut agents = routing_workflow(agent_count, Vec::new()).agents;
        agents.push(routing_agent(repeated, StepKind::Agent));

        let workflow = workflow_from_parts(agents, Vec::new());
        let verdict = validate_workflow(&workflow);

        prop_assert_eq!(
            verdict,
            Err(WorkflowProblem::DuplicateAgentId {
                agent_id: agent_identifier(repeated),
            })
        );
    }

    #[test]
    fn test_validate_connection_property_names_the_first_unknown_end(
        agent_count in 1..=LARGEST_AGENT_COUNT,
        known in 0..LARGEST_AGENT_COUNT,
        is_from_unknown in any::<bool>(),
        is_to_unknown in any::<bool>(),
    ) {
        prop_assume!(is_from_unknown || is_to_unknown);
        let known = known % agent_count;
        let from = if is_from_unknown { UNKNOWN_NUMBER } else { known };
        let to = if is_to_unknown { UNKNOWN_NUMBER + 1 } else { known };
        let workflow =
            routing_workflow(agent_count, vec![connect(from, to, None, None)]);

        let verdict = validate_workflow(&workflow);

        let unknown = if is_from_unknown { from } else { to };
        prop_assert_eq!(
            verdict,
            Err(WorkflowProblem::UnknownConnectionEnd {
                agent_id: agent_identifier(unknown),
            })
        );
    }

    #[test]
    fn test_validate_connection_property_a_self_loop_is_a_self_connection(
        agent_count in 1..=LARGEST_AGENT_COUNT,
        looped in 0..LARGEST_AGENT_COUNT,
        round_limit in proptest::option::of(1..=10_u32),
    ) {
        let looped = looped % agent_count;
        let condition = round_limit.map(|_| BACK_OUTCOME);
        let connection = connect(looped, looped, condition, round_limit);
        let workflow = routing_workflow(agent_count, vec![connection]);

        let verdict = validate_workflow(&workflow);

        prop_assert_eq!(
            verdict,
            Err(WorkflowProblem::SelfConnection {
                agent_id: agent_identifier(looped),
            })
        );
    }

    #[test]
    fn test_validate_connection_property_unknown_ends_come_before_self(
        agent_count in 1..=LARGEST_AGENT_COUNT,
    ) {
        let unknown = connect(UNKNOWN_NUMBER, UNKNOWN_NUMBER, None, None);
        let workflow = routing_workflow(agent_count, vec![unknown]);

        let verdict = validate_workflow(&workflow);

        prop_assert_eq!(
            verdict,
            Err(WorkflowProblem::UnknownConnectionEnd {
                agent_id: agent_identifier(UNKNOWN_NUMBER),
            })
        );
    }

    #[test]
    fn test_has_cycle_property_agrees_with_a_depth_first_search(
        (agent_count, edges) in graph(),
    ) {
        let mut connections = Vec::new();
        for (from, to) in &edges {
            connections.push(connect(*from, *to, None, None));
        }
        let workflow = routing_workflow(agent_count, connections);

        let is_cycle =
            validate_workflow(&workflow) == Err(WorkflowProblem::Cycle);

        let expected = has_cycle_by_depth_search(agent_count, &edges);
        prop_assert_eq!(is_cycle, expected);
        prop_assert_eq!(validate_workflow(&workflow).is_ok(), !is_cycle);
    }

    #[test]
    fn test_has_cycle_property_conditions_never_excuse_a_cycle(
        (agent_count, edges) in graph(),
    ) {
        let mut connections = Vec::new();
        for (position, (from, to)) in edges.iter().enumerate() {
            let outcome = outcome_for(position);
            connections.push(connect(*from, *to, Some(&outcome), None));
        }
        let workflow = routing_workflow(agent_count, connections);

        let is_cycle =
            validate_workflow(&workflow) == Err(WorkflowProblem::Cycle);

        let expected = has_cycle_by_depth_search(agent_count, &edges);
        prop_assert_eq!(is_cycle, expected);
    }

    #[test]
    fn test_has_cycle_property_a_round_limit_turns_a_back_edge_into_a_loop(
        chain_length in 2..=LARGEST_AGENT_COUNT,
        target in 0..LARGEST_AGENT_COUNT,
    ) {
        let source = chain_length - 1;
        let target = target % source;
        let mut connections = Vec::new();
        for number in 1..chain_length {
            connections.push(connect(number - 1, number, None, None));
        }
        let back_edge = connect(source, target, Some(BACK_OUTCOME), None);
        let back_loop = AgentConnection {
            round_limit: Some(LOOP_ROUNDS),
            ..back_edge.clone()
        };
        let mut with_edge = connections.clone();
        with_edge.push(back_edge);
        connections.push(back_loop);

        let edge_workflow = routing_workflow(chain_length, with_edge);
        let edge_verdict = validate_workflow(&edge_workflow);
        let loop_verdict =
            validate_workflow(&routing_workflow(chain_length, connections));

        prop_assert_eq!(edge_verdict, Err(WorkflowProblem::Cycle));
        prop_assert_eq!(loop_verdict, Ok(()));
    }
}
