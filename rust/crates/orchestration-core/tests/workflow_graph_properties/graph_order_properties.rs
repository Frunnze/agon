use std::collections::BTreeSet;

use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::{AgentConnection, Workflow, WorkflowAgent};
use orchestration_core::workflow_graph::{
    agents_in_order, forward_connections, forward_reachable_agents,
};
use proptest::prelude::*;

use crate::branching_strategies::{branching_plan, build_branching_workflow};
use crate::canvas_reading::{compare_by_canvas, list_order_ids, repositioned};
use crate::workflow_strategies::{
    agent_identifier, arbitrary_workflow, workflow_from_parts,
    workflow_with_cycle,
};

const UNKNOWN_NUMBER: u128 = 999;

fn valid_workflow_anywhere() -> impl Strategy<Value = Workflow> {
    branching_plan()
        .prop_map(|plan| build_branching_workflow(&plan))
        .prop_flat_map(repositioned)
}

fn order_by_kahn(workflow: &Workflow) -> Vec<WorkflowAgentId> {
    let mut ranked: Vec<&WorkflowAgent> = workflow.agents.iter().collect();
    ranked.sort_by(|first, second| compare_by_canvas(first, second));
    let forward = forward_connections(workflow);
    let mut missing_inputs = vec![0_usize; ranked.len()];
    for (rank, agent) in ranked.iter().enumerate() {
        missing_inputs[rank] = forward
            .iter()
            .filter(|connection| connection.to == agent.id)
            .count();
    }

    let mut ready: BTreeSet<usize> = BTreeSet::new();
    for (rank, missing) in missing_inputs.iter().enumerate() {
        if *missing == 0 {
            ready.insert(rank);
        }
    }
    let mut ordered = Vec::new();
    while let Some(rank) = ready.pop_first() {
        let agent_id = ranked[rank].id;
        ordered.push(agent_id);
        let outputs = forward.iter().filter(|output| output.from == agent_id);
        for connection in outputs {
            for (target_rank, target) in ranked.iter().enumerate() {
                if target.id == connection.to {
                    missing_inputs[target_rank] -= 1;
                    if missing_inputs[target_rank] == 0 {
                        ready.insert(target_rank);
                    }
                }
            }
        }
    }
    ordered
}

fn find_order_position(
    order: &[WorkflowAgentId],
    agent_id: WorkflowAgentId,
) -> usize {
    order
        .iter()
        .position(|id| *id == agent_id)
        .unwrap_or(usize::MAX)
}

fn list_cycle_reached(workflow: &Workflow) -> BTreeSet<WorkflowAgentId> {
    let mut cycle_reached = BTreeSet::new();
    for agent in &workflow.agents {
        let reached = forward_reachable_agents(workflow, agent.id);
        let is_on_cycle =
            forward_connections(workflow).iter().any(|connection| {
                connection.to == agent.id && reached.contains(&connection.from)
            });
        if is_on_cycle {
            cycle_reached.extend(reached);
        }
    }
    cycle_reached
}

proptest! {
    #[test]
    fn test_find_ready_index_property_matches_the_kahn_reference(
        workflow in valid_workflow_anywhere(),
    ) {
        prop_assert_eq!(list_order_ids(&workflow), order_by_kahn(&workflow));
    }

    #[test]
    fn test_find_ready_index_property_lists_every_agent_once_regardless(
        workflow in arbitrary_workflow(),
        fed_position in any::<prop::sample::Index>(),
    ) {
        let mut connections = workflow.connections.clone();
        if !workflow.agents.is_empty() {
            let fed_index = fed_position.index(workflow.agents.len());
            let fed = &workflow.agents[fed_index];
            connections.push(AgentConnection::plain(
                agent_identifier(UNKNOWN_NUMBER),
                fed.id,
            ));
        }
        let fed_from_outside =
            workflow_from_parts(workflow.agents.clone(), connections);

        let ordered = agents_in_order(&fed_from_outside);

        prop_assert_eq!(ordered.len(), workflow.agents.len());
        for agent in &fed_from_outside.agents {
            let copies = ordered
                .iter()
                .filter(|listed| std::ptr::eq(**listed, agent))
                .count();
            prop_assert_eq!(copies, 1);
        }
    }

    #[test]
    fn test_find_ready_index_property_agents_clear_of_cycles_come_first(
        workflow in workflow_with_cycle(),
    ) {
        let order = list_order_ids(&workflow);
        let cycle_reached = list_cycle_reached(&workflow);

        let mut has_seen_cycle_agent = false;
        for agent_id in order {
            let is_cycle_agent = cycle_reached.contains(&agent_id);
            prop_assert!(is_cycle_agent || !has_seen_cycle_agent);
            has_seen_cycle_agent = has_seen_cycle_agent || is_cycle_agent;
        }
    }

    #[test]
    fn test_has_all_upstream_placed_property_inputs_come_first(
        workflow in valid_workflow_anywhere(),
    ) {
        let order = list_order_ids(&workflow);

        for connection in forward_connections(&workflow) {
            let from_position = find_order_position(&order, connection.from);
            let to_position = find_order_position(&order, connection.to);
            prop_assert!(from_position < to_position);
        }
    }

    #[test]
    fn test_has_all_upstream_placed_property_a_loop_never_holds_its_target(
        workflow in valid_workflow_anywhere(),
    ) {
        let order = list_order_ids(&workflow);

        let loops = workflow.connections.iter().filter(|link| link.is_loop());
        for connection in loops {
            let from_position = find_order_position(&order, connection.from);
            let to_position = find_order_position(&order, connection.to);
            prop_assert!(to_position < from_position);
        }
    }

    #[test]
    fn test_has_all_upstream_placed_property_an_agreeing_input_keeps_order(
        workflow in valid_workflow_anywhere(),
        picks in (any::<prop::sample::Index>(), any::<prop::sample::Index>()),
    ) {
        let order = list_order_ids(&workflow);
        let first = picks.0.index(order.len());
        let second = picks.1.index(order.len());
        if first == second {
            return Ok(());
        }
        let (earlier, later) = (first.min(second), first.max(second));
        let mut connections = workflow.connections.clone();
        connections.push(AgentConnection::plain(order[earlier], order[later]));

        let constrained =
            workflow_from_parts(workflow.agents.clone(), connections);

        prop_assert_eq!(list_order_ids(&constrained), order);
    }

}
