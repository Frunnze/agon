use std::collections::BTreeSet;
use std::ptr;

use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::{AgentConnection, Workflow};
use orchestration_core::workflow_graph::{
    find_agent_by_id, forward_connections, forward_reachable_agents,
    loops_rerunning_agent, upstream_agents,
};
use proptest::prelude::*;

use crate::branching_strategies::{branching_plan, build_branching_workflow};
use crate::workflow_strategies::{
    acyclic_workflow, agent_identifier, arbitrary_workflow,
    workflow_from_parts,
};

const UNUSED_AGENT_NUMBER: u128 = 1_000_000;
const LARGEST_LOOKUP_NUMBER: u128 = 8;

type AgentIds = BTreeSet<WorkflowAgentId>;

fn valid_branching_workflow() -> impl Strategy<Value = Workflow> {
    branching_plan().prop_map(|plan| build_branching_workflow(&plan))
}

fn strip_loops(workflow: &Workflow) -> Workflow {
    let forward: Vec<AgentConnection> = workflow
        .connections
        .iter()
        .filter(|connection| !connection.is_loop())
        .cloned()
        .collect();
    workflow_from_parts(workflow.agents.clone(), forward)
}

fn reach_by_fixed_point(
    workflow: &Workflow,
    start: WorkflowAgentId,
) -> AgentIds {
    let mut reached = AgentIds::from([start]);
    let mut has_grown = true;
    while has_grown {
        has_grown = false;
        for connection in &workflow.connections {
            let is_forward = connection.round_limit.is_none();
            if is_forward
                && reached.contains(&connection.from)
                && reached.insert(connection.to)
            {
                has_grown = true;
            }
        }
    }
    reached
}

fn list_upstream_ids(
    workflow: &Workflow,
    agent_id: WorkflowAgentId,
) -> Vec<WorkflowAgentId> {
    upstream_agents(workflow, agent_id)
        .iter()
        .map(|agent| agent.id)
        .collect()
}

fn pick_agent_id(
    workflow: &Workflow,
    pick: prop::sample::Index,
) -> WorkflowAgentId {
    workflow.agents[pick.index(workflow.agents.len())].id
}

proptest! {
    #[test]
    fn test_forward_connections_property_keeps_every_non_loop_in_order(
        workflow in valid_branching_workflow(),
    ) {
        let forward = forward_connections(&workflow);

        let expected: Vec<&AgentConnection> = workflow
            .connections
            .iter()
            .filter(|connection| connection.round_limit.is_none())
            .collect();
        prop_assert_eq!(forward, expected);
    }

    #[test]
    fn test_forward_connections_property_a_loopless_workflow_keeps_all(
        workflow in acyclic_workflow(),
    ) {
        let forward = forward_connections(&workflow);

        let all: Vec<&AgentConnection> = workflow.connections.iter().collect();
        prop_assert_eq!(forward, all);
    }

    #[test]
    fn test_forward_connections_property_loops_never_change_the_answer(
        workflow in valid_branching_workflow(),
    ) {
        let without_loops = strip_loops(&workflow);

        let forward = forward_connections(&workflow);
        let forward_without_loops = forward_connections(&without_loops);

        prop_assert_eq!(forward, forward_without_loops);
    }

    #[test]
    fn test_find_agent_by_id_property_finds_every_stored_agent(
        workflow in valid_branching_workflow(),
    ) {
        for agent in &workflow.agents {
            let found = find_agent_by_id(&workflow, agent.id);

            prop_assert!(found.is_some_and(|found| ptr::eq(found, agent)));
        }
    }

    #[test]
    fn test_find_agent_by_id_property_an_unknown_id_finds_nothing(
        workflow in arbitrary_workflow(),
    ) {
        let unknown_id = agent_identifier(UNUSED_AGENT_NUMBER);

        prop_assert!(find_agent_by_id(&workflow, unknown_id).is_none());
    }

    #[test]
    fn test_find_agent_by_id_property_answers_carry_the_asked_id(
        workflow in arbitrary_workflow(),
        number in 0..LARGEST_LOOKUP_NUMBER,
    ) {
        let asked_id = agent_identifier(number);

        let found = find_agent_by_id(&workflow, asked_id);

        let is_stored =
            workflow.agents.iter().any(|agent| agent.id == asked_id);
        prop_assert_eq!(found.is_some(), is_stored);
        prop_assert!(found.is_none_or(|agent| agent.id == asked_id));
    }

    #[test]
    fn test_forward_reachable_agents_property_matches_a_fixed_point(
        workflow in
            prop_oneof![valid_branching_workflow(), arbitrary_workflow()],
        number in 0..LARGEST_LOOKUP_NUMBER,
    ) {
        let start = agent_identifier(number);

        let reached = forward_reachable_agents(&workflow, start);

        prop_assert_eq!(reached, reach_by_fixed_point(&workflow, start));
    }

    #[test]
    fn test_forward_reachable_agents_property_reach_is_transitive(
        workflow in valid_branching_workflow(),
        pick in any::<prop::sample::Index>(),
    ) {
        let start = pick_agent_id(&workflow, pick);

        let reached = forward_reachable_agents(&workflow, start);

        for reached_id in &reached {
            let reached_further =
                forward_reachable_agents(&workflow, *reached_id);
            prop_assert!(reached_further.is_subset(&reached));
        }
        prop_assert!(reached.contains(&start));
    }

    #[test]
    fn test_forward_reachable_agents_property_loops_never_reach_further(
        workflow in valid_branching_workflow(),
        pick in any::<prop::sample::Index>(),
    ) {
        let start = pick_agent_id(&workflow, pick);

        let reached = forward_reachable_agents(&workflow, start);
        let reached_without_loops =
            forward_reachable_agents(&strip_loops(&workflow), start);

        prop_assert_eq!(reached, reached_without_loops);
    }

    #[test]
    fn test_loops_rerunning_agent_property_lists_only_loops_in_order(
        workflow in valid_branching_workflow(),
        pick in any::<prop::sample::Index>(),
    ) {
        let agent_id = pick_agent_id(&workflow, pick);

        let rerunning_loops = loops_rerunning_agent(&workflow, agent_id);

        let loops: Vec<&AgentConnection> = workflow
            .connections
            .iter()
            .filter(|connection| connection.is_loop())
            .collect();
        let mut remaining_loops = loops.iter();
        for rerunning_loop in rerunning_loops {
            prop_assert!(rerunning_loop.is_loop());
            let is_in_order = remaining_loops
                .any(|candidate| ptr::eq(*candidate, rerunning_loop));
            prop_assert!(is_in_order);
        }
    }

    #[test]
    fn test_loops_rerunning_agent_property_a_loop_reruns_both_its_ends(
        workflow in valid_branching_workflow(),
    ) {
        let loops = workflow.connections.iter().filter(|link| link.is_loop());
        for connection in loops {
            for end in [connection.from, connection.to] {
                let rerunning_loops = loops_rerunning_agent(&workflow, end);
                let is_listed = rerunning_loops
                    .iter()
                    .any(|rerunning| ptr::eq(*rerunning, connection));
                prop_assert!(is_listed);
            }
        }
    }

    #[test]
    fn test_loops_rerunning_agent_property_a_loopless_workflow_reruns_none(
        workflow in valid_branching_workflow(),
        pick in any::<prop::sample::Index>(),
    ) {
        let without_loops = strip_loops(&workflow);
        let agent_id = pick_agent_id(&without_loops, pick);

        let rerunning_loops = loops_rerunning_agent(&without_loops, agent_id);
        prop_assert!(rerunning_loops.is_empty());
    }

    #[test]
    fn test_upstream_agents_property_loops_never_add_an_upstream(
        workflow in valid_branching_workflow(),
        pick in any::<prop::sample::Index>(),
    ) {
        let agent_id = pick_agent_id(&workflow, pick);
        let without_loops = strip_loops(&workflow);

        let upstream = list_upstream_ids(&workflow, agent_id);
        let upstream_without_loops =
            list_upstream_ids(&without_loops, agent_id);

        prop_assert_eq!(upstream, upstream_without_loops);
    }

    #[test]
    fn test_upstream_agents_property_an_unknown_agent_has_no_upstream(
        workflow in arbitrary_workflow(),
    ) {
        let unknown_id = agent_identifier(UNUSED_AGENT_NUMBER);

        prop_assert!(upstream_agents(&workflow, unknown_id).is_empty());
    }
}
