use std::ptr;

use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::{AgentConnection, Workflow, WorkflowAgent};
use orchestration_core::workflow_graph::{
    WorkflowProblem, agents_in_order, upstream_agents, validate_workflow,
};
use proptest::prelude::*;

use crate::workflow_strategies::{
    acyclic_workflow, agent_identifier, arbitrary_workflow,
    workflow_from_parts, workflow_with_cycle,
};

const FUZZ_TARGET_IDENTIFIERS: u128 = 8;

fn position_in(
    ordered: &[&WorkflowAgent],
    agent_id: WorkflowAgentId,
) -> Option<usize> {
    ordered.iter().position(|agent| agent.id == agent_id)
}

fn is_permutation_of_agents(
    ordered: &[&WorkflowAgent],
    workflow: &Workflow,
) -> bool {
    let every_agent_once = workflow.agents.iter().all(|agent| {
        let appearances = ordered
            .iter()
            .filter(|ordered_agent| ptr::eq(**ordered_agent, agent))
            .count();
        appearances == 1
    });
    every_agent_once && ordered.len() == workflow.agents.len()
}

fn respects_connections(
    ordered: &[&WorkflowAgent],
    connections: &[AgentConnection],
) -> bool {
    connections.iter().all(|connection| {
        let from_position = position_in(ordered, connection.from);
        let to_position = position_in(ordered, connection.to);
        from_position < to_position
    })
}

fn with_connection(
    workflow: &Workflow,
    connection: AgentConnection,
) -> Workflow {
    let mut connections = workflow.connections.clone();
    connections.push(connection);
    Workflow {
        connections,
        ..workflow.clone()
    }
}

#[test]
fn test_validate_workflow_rejects_a_workflow_without_agents() {
    let workflow = workflow_from_parts(Vec::new(), Vec::new());

    assert_eq!(validate_workflow(&workflow), Err(WorkflowProblem::NoAgents));
}

proptest! {
    #[test]
    fn test_validate_workflow_property_accepts_acyclic_workflows(
        workflow in acyclic_workflow(),
    ) {
        prop_assert_eq!(validate_workflow(&workflow), Ok(()));
    }

    #[test]
    fn test_validate_workflow_property_rejects_cycles(
        workflow in workflow_with_cycle(),
    ) {
        let verdict = validate_workflow(&workflow);

        prop_assert_eq!(verdict, Err(WorkflowProblem::Cycle));
    }

    #[test]
    fn test_validate_workflow_property_rejects_self_connections(
        workflow in acyclic_workflow(),
        chosen in any::<prop::sample::Index>(),
    ) {
        let agent_id = workflow.agents[chosen.index(workflow.agents.len())].id;
        let looped = with_connection(
            &workflow,
            AgentConnection::plain(agent_id, agent_id),
        );

        prop_assert_eq!(
            validate_workflow(&looped),
            Err(WorkflowProblem::SelfConnection { agent_id })
        );
    }

    #[test]
    fn test_validate_workflow_property_rejects_unknown_connection_ends(
        workflow in acyclic_workflow(),
        chosen in any::<prop::sample::Index>(),
    ) {
        let known_id = workflow.agents[chosen.index(workflow.agents.len())].id;
        let unknown_id = agent_identifier(u128::MAX);
        let dangling = with_connection(
            &workflow,
            AgentConnection::plain(known_id, unknown_id),
        );

        prop_assert_eq!(
            validate_workflow(&dangling),
            Err(WorkflowProblem::UnknownConnectionEnd { agent_id: unknown_id })
        );
    }

    #[test]
    fn test_validate_workflow_property_rejects_repeated_agent_names(
        workflow in acyclic_workflow(),
        chosen in any::<prop::sample::Index>(),
    ) {
        let first_name = workflow.agents[0].name.clone();
        let renamed_index = chosen.index(workflow.agents.len());
        let mut agents = workflow.agents.clone();
        agents[renamed_index].name.clone_from(&first_name);
        let renamed = Workflow { agents, ..workflow.clone() };

        let verdict = validate_workflow(&renamed);

        if renamed_index == 0 {
            prop_assert_eq!(verdict, Ok(()));
        } else {
            prop_assert_eq!(
                verdict,
                Err(WorkflowProblem::DuplicateAgentName { name: first_name })
            );
        }
    }

    #[test]
    fn test_validate_workflow_fuzz_valid_verdicts_have_a_full_order(
        workflow in arbitrary_workflow(),
    ) {
        let verdict = validate_workflow(&workflow);

        if verdict.is_ok() {
            let ordered = agents_in_order(&workflow);
            let connections = &workflow.connections;
            prop_assert!(respects_connections(&ordered, connections));
        }
    }

    #[test]
    fn test_agents_in_order_property_upstream_agents_come_first(
        workflow in acyclic_workflow(),
    ) {
        let ordered = agents_in_order(&workflow);

        prop_assert!(is_permutation_of_agents(&ordered, &workflow));
        prop_assert!(respects_connections(&ordered, &workflow.connections));
    }

    #[test]
    fn test_agents_in_order_property_unconnected_agents_follow_the_canvas(
        workflow in acyclic_workflow(),
    ) {
        let unconnected = Workflow {
            connections: Vec::new(),
            ..workflow.clone()
        };

        let ordered = agents_in_order(&unconnected);

        for pair in ordered.windows(2) {
            let earlier = pair[0].position;
            let later = pair[1].position;
            let earlier_key = (earlier.vertical, earlier.horizontal);
            let later_key = (later.vertical, later.horizontal);
            prop_assert!(earlier_key <= later_key);
        }
    }

    #[test]
    fn test_agents_in_order_property_ignores_the_order_agents_are_stored(
        workflow in acyclic_workflow(),
    ) {
        let mut reversed_agents = workflow.agents.clone();
        reversed_agents.reverse();
        let reversed = Workflow {
            agents: reversed_agents,
            ..workflow.clone()
        };

        let original_names: Vec<&str> = agents_in_order(&workflow)
            .iter()
            .map(|agent| agent.name.as_str())
            .collect();
        let reversed_names: Vec<&str> = agents_in_order(&reversed)
            .iter()
            .map(|agent| agent.name.as_str())
            .collect();

        prop_assert_eq!(original_names, reversed_names);
    }

    #[test]
    fn test_agents_in_order_fuzz_always_returns_every_agent_once(
        workflow in arbitrary_workflow(),
    ) {
        let ordered = agents_in_order(&workflow);

        prop_assert!(is_permutation_of_agents(&ordered, &workflow));
    }

    #[test]
    fn test_upstream_agents_property_returns_exactly_the_connected_agents(
        workflow in acyclic_workflow(),
        chosen in any::<prop::sample::Index>(),
    ) {
        let target_index = chosen.index(workflow.agents.len());
        let target_id = workflow.agents[target_index].id;

        let upstream = upstream_agents(&workflow, target_id);

        for agent in &workflow.agents {
            let is_connected = workflow.connections.iter().any(|connection| {
                connection.from == agent.id && connection.to == target_id
            });
            let is_listed =
                upstream.iter().any(|listed| listed.id == agent.id);
            prop_assert_eq!(is_listed, is_connected);
        }
    }

    #[test]
    fn test_upstream_agents_property_lists_agents_in_run_order(
        workflow in acyclic_workflow(),
        chosen in any::<prop::sample::Index>(),
    ) {
        let target_index = chosen.index(workflow.agents.len());
        let target_id = workflow.agents[target_index].id;
        let ordered = agents_in_order(&workflow);

        let upstream = upstream_agents(&workflow, target_id);

        let positions: Vec<Option<usize>> = upstream
            .iter()
            .map(|agent| position_in(&ordered, agent.id))
            .collect();
        for pair in positions.windows(2) {
            prop_assert!(pair[0] < pair[1]);
        }
    }

    #[test]
    fn test_upstream_agents_fuzz_lists_each_agent_at_most_once(
        workflow in arbitrary_workflow(),
        target_id in (0..FUZZ_TARGET_IDENTIFIERS).prop_map(agent_identifier),
    ) {
        let upstream = upstream_agents(&workflow, target_id);

        prop_assert!(upstream.len() <= workflow.agents.len());
        for agent in &upstream {
            let appearances = upstream
                .iter()
                .filter(|other| ptr::eq(**other, *agent))
                .count();
            prop_assert_eq!(appearances, 1);
        }
    }
}
