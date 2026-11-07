use std::cmp::Ordering;
use std::collections::BTreeSet;

use thiserror::Error;

use crate::connection_rules::{
    validate_conditions, validate_distinct_step_pairs, validate_loops,
};
use crate::identifiers::WorkflowAgentId;
use crate::naming::{NameProblem, validate_name};
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
    #[error("the step name {name:?} breaks the naming rule: {problem}")]
    InvalidStepName { name: String, problem: NameProblem },
    #[error("a connection points to the unknown agent {}", .agent_id.0)]
    UnknownConnectionEnd { agent_id: WorkflowAgentId },
    #[error("agent {} is connected to itself", .agent_id.0)]
    SelfConnection { agent_id: WorkflowAgentId },
    #[error("there are two connections from {from} to {to}; keep one")]
    RepeatedConnection { from: String, to: String },
    #[error("the connections form a cycle")]
    Cycle,
    #[error(
        "the outcome {condition:?} must be 1 to 40 lowercase letters, \
         digits, spaces or dashes, without a space at either end"
    )]
    InvalidCondition { condition: String },
    #[error(
        "two connections out of {step_name} share the outcome {condition}"
    )]
    DuplicateCondition {
        step_name: String,
        condition: String,
    },
    #[error("a loop connection needs an outcome that takes it")]
    LoopWithoutCondition,
    #[error("a loop allows 1 to 10 rounds, not {round_limit}")]
    InvalidRoundLimit { round_limit: u32 },
    #[error("the loop from {from} to {to} must point back to an earlier step")]
    LoopPointsForward { from: String, to: String },
}

pub fn validate_workflow(workflow: &Workflow) -> Result<(), WorkflowProblem> {
    if workflow.agents.is_empty() {
        return Err(WorkflowProblem::NoAgents);
    }
    validate_unique_agents(&workflow.agents)?;
    validate_step_names(&workflow.agents)?;
    for connection in &workflow.connections {
        validate_connection(connection, &workflow.agents)?;
    }
    validate_conditions(workflow)?;
    if has_cycle(workflow) {
        return Err(WorkflowProblem::Cycle);
    }
    validate_loops(workflow)?;
    validate_distinct_step_pairs(workflow)
}

#[must_use]
pub fn forward_connections(workflow: &Workflow) -> Vec<&AgentConnection> {
    workflow
        .connections
        .iter()
        .filter(|connection| !connection.is_loop())
        .collect()
}

#[must_use]
pub fn agents_in_order(workflow: &Workflow) -> Vec<&WorkflowAgent> {
    let mut remaining: Vec<&WorkflowAgent> = workflow.agents.iter().collect();
    remaining.sort_by(|first, second| compare_canvas_order(first, second));
    let connections = forward_connections(workflow);

    let mut ordered: Vec<&WorkflowAgent> = Vec::new();
    while !remaining.is_empty() {
        let ready_index = find_ready_index(&remaining, &ordered, &connections)
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
    let connections = forward_connections(workflow);
    agents_in_order(workflow)
        .into_iter()
        .filter(|candidate| {
            connections.iter().any(|connection| {
                connection.from == candidate.id && connection.to == agent_id
            })
        })
        .collect()
}

#[must_use]
pub fn forward_reachable_agents(
    workflow: &Workflow,
    start: WorkflowAgentId,
) -> BTreeSet<WorkflowAgentId> {
    let connections = forward_connections(workflow);
    let mut reached = BTreeSet::from([start]);
    let mut frontier = vec![start];
    while let Some(agent_id) = frontier.pop() {
        for connection in &connections {
            let is_new =
                connection.from == agent_id && reached.insert(connection.to);
            if is_new {
                frontier.push(connection.to);
            }
        }
    }
    reached
}

#[must_use]
pub fn loops_rerunning_agent(
    workflow: &Workflow,
    agent_id: WorkflowAgentId,
) -> Vec<&AgentConnection> {
    let mut rerunning_loops = Vec::new();
    for connection in &workflow.connections {
        if !connection.is_loop() {
            continue;
        }
        let rerun_agents = forward_reachable_agents(workflow, connection.to);
        if rerun_agents.contains(&agent_id) {
            rerunning_loops.push(connection);
        }
    }
    rerunning_loops
}

#[must_use]
pub fn find_agent_by_id(
    workflow: &Workflow,
    agent_id: WorkflowAgentId,
) -> Option<&WorkflowAgent> {
    workflow.agents.iter().find(|agent| agent.id == agent_id)
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

fn validate_step_names(
    agents: &[WorkflowAgent],
) -> Result<(), WorkflowProblem> {
    for agent in agents {
        validate_name(&agent.name).map_err(|problem| {
            WorkflowProblem::InvalidStepName {
                name: agent.name.clone(),
                problem,
            }
        })?;
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
    let connections = forward_connections(workflow);
    let mut remaining: Vec<&WorkflowAgent> = workflow.agents.iter().collect();
    let mut placed: Vec<&WorkflowAgent> = Vec::new();
    while let Some(ready_index) =
        find_ready_index(&remaining, &placed, &connections)
    {
        placed.push(remaining.remove(ready_index));
    }
    !remaining.is_empty()
}

fn find_ready_index(
    remaining: &[&WorkflowAgent],
    placed: &[&WorkflowAgent],
    connections: &[&AgentConnection],
) -> Option<usize> {
    remaining
        .iter()
        .position(|agent| has_all_upstream_placed(agent, placed, connections))
}

fn has_all_upstream_placed(
    agent: &WorkflowAgent,
    placed: &[&WorkflowAgent],
    connections: &[&AgentConnection],
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
