use std::cmp::Ordering;
use std::collections::BTreeSet;

use thiserror::Error;

use crate::identifiers::WorkflowAgentId;
use crate::workflow::{AgentConnection, Workflow, WorkflowAgent};

const EARLIEST_REMAINING_INDEX: usize = 0;

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum WorkflowProblem {
    #[error("the workflow has no agents")]
    NoAgents,
    #[error("two agents share the id {}", .agent_id.0)]
    DuplicateAgentId { agent_id: WorkflowAgentId },
    #[error("two agents are named {name}")]
    DuplicateAgentName { name: String },
    #[error("a connection points to the unknown agent {}", .agent_id.0)]
    UnknownConnectionEnd { agent_id: WorkflowAgentId },
    #[error("agent {} is connected to itself", .agent_id.0)]
    SelfConnection { agent_id: WorkflowAgentId },
    #[error("the connections form a cycle")]
    Cycle,
}

pub fn validate_workflow(workflow: &Workflow) -> Result<(), WorkflowProblem> {
    if workflow.agents.is_empty() {
        return Err(WorkflowProblem::NoAgents);
    }
    validate_unique_agents(&workflow.agents)?;
    for connection in &workflow.connections {
        validate_connection(connection, &workflow.agents)?;
    }
    if has_cycle(workflow) {
        return Err(WorkflowProblem::Cycle);
    }
    Ok(())
}

#[must_use]
pub fn agents_in_order(workflow: &Workflow) -> Vec<&WorkflowAgent> {
    let mut remaining: Vec<&WorkflowAgent> = workflow.agents.iter().collect();
    remaining.sort_by(|first, second| compare_canvas_order(first, second));

    let mut ordered: Vec<&WorkflowAgent> = Vec::new();
    while !remaining.is_empty() {
        let ready_index =
            find_ready_index(&remaining, &ordered, &workflow.connections)
                .unwrap_or(EARLIEST_REMAINING_INDEX);
        ordered.push(remaining.remove(ready_index));
    }
    ordered
}

#[must_use]
pub fn upstream_agents(
    workflow: &Workflow,
    agent_id: WorkflowAgentId,
) -> Vec<&WorkflowAgent> {
    agents_in_order(workflow)
        .into_iter()
        .filter(|candidate| {
            workflow.connections.iter().any(|connection| {
                connection.from == candidate.id && connection.to == agent_id
            })
        })
        .collect()
}

fn validate_unique_agents(
    agents: &[WorkflowAgent],
) -> Result<(), WorkflowProblem> {
    let mut seen_ids: BTreeSet<WorkflowAgentId> = BTreeSet::new();
    let mut seen_names: BTreeSet<&str> = BTreeSet::new();
    for agent in agents {
        if !seen_ids.insert(agent.id) {
            return Err(WorkflowProblem::DuplicateAgentId {
                agent_id: agent.id,
            });
        }
        if !seen_names.insert(agent.name.as_str()) {
            return Err(WorkflowProblem::DuplicateAgentName {
                name: agent.name.clone(),
            });
        }
    }
    Ok(())
}

fn validate_connection(
    connection: &AgentConnection,
    agents: &[WorkflowAgent],
) -> Result<(), WorkflowProblem> {
    for agent_id in [connection.from, connection.to] {
        let is_known = agents.iter().any(|agent| agent.id == agent_id);
        if !is_known {
            return Err(WorkflowProblem::UnknownConnectionEnd { agent_id });
        }
    }
    if connection.from == connection.to {
        return Err(WorkflowProblem::SelfConnection {
            agent_id: connection.from,
        });
    }
    Ok(())
}

fn has_cycle(workflow: &Workflow) -> bool {
    let mut remaining: Vec<&WorkflowAgent> = workflow.agents.iter().collect();
    let mut placed: Vec<&WorkflowAgent> = Vec::new();
    while let Some(ready_index) =
        find_ready_index(&remaining, &placed, &workflow.connections)
    {
        placed.push(remaining.remove(ready_index));
    }
    !remaining.is_empty()
}

fn find_ready_index(
    remaining: &[&WorkflowAgent],
    placed: &[&WorkflowAgent],
    connections: &[AgentConnection],
) -> Option<usize> {
    remaining
        .iter()
        .position(|agent| has_all_upstream_placed(agent, placed, connections))
}

fn has_all_upstream_placed(
    agent: &WorkflowAgent,
    placed: &[&WorkflowAgent],
    connections: &[AgentConnection],
) -> bool {
    connections
        .iter()
        .filter(|connection| connection.to == agent.id)
        .all(|connection| {
            placed
                .iter()
                .any(|placed_agent| placed_agent.id == connection.from)
        })
}

fn compare_canvas_order(
    first: &WorkflowAgent,
    second: &WorkflowAgent,
) -> Ordering {
    let vertical_order =
        first.position.vertical.total_cmp(&second.position.vertical);
    let horizontal_order = first
        .position
        .horizontal
        .total_cmp(&second.position.horizontal);
    vertical_order
        .then(horizontal_order)
        .then_with(|| first.name.cmp(&second.name))
        .then_with(|| first.id.cmp(&second.id))
}
