use std::collections::BTreeSet;

use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::{AgentConnection, Workflow};
use orchestration_core::workflow_graph::find_agent_by_id;
use proptest::prelude::*;

use crate::routing_fixtures::connect;

pub type NamedConnection = (String, String, Option<String>, Option<u32>);

pub const CONDITION_CHOICES: [Option<&str>; 3] =
    [None, Some("approved"), Some("changes")];
const SMALLEST_AGENT_COUNT: u128 = 2;
const LARGEST_AGENT_COUNT: u128 = 4;
const UNKNOWN_STEP_NAME: &str = "unknown";

pub fn name_agent(workflow: &Workflow, agent_id: WorkflowAgentId) -> String {
    find_agent_by_id(workflow, agent_id).map_or_else(
        || UNKNOWN_STEP_NAME.to_owned(),
        |agent| agent.name.clone(),
    )
}

pub fn list_named_connections(
    workflow: &Workflow,
) -> BTreeSet<NamedConnection> {
    let mut named_connections = BTreeSet::new();
    for connection in &workflow.connections {
        named_connections.insert((
            name_agent(workflow, connection.from),
            name_agent(workflow, connection.to),
            connection.condition.clone(),
            connection.round_limit,
        ));
    }
    named_connections
}

pub fn list_candidate_connections(agent_count: u128) -> Vec<AgentConnection> {
    let mut candidates = Vec::new();
    for from in 0..agent_count {
        for to in (from + 1)..agent_count {
            for condition in CONDITION_CHOICES {
                candidates.push(connect(from, to, condition, None));
            }
        }
    }
    candidates
}

pub fn pick_connections(
    candidates: &[AgentConnection],
    picks: &[bool],
) -> Vec<AgentConnection> {
    let mut picked = Vec::new();
    for (candidate, is_picked) in candidates.iter().zip(picks) {
        if *is_picked {
            picked.push(candidate.clone());
        }
    }
    picked
}

pub fn agent_count() -> impl Strategy<Value = u128> {
    SMALLEST_AGENT_COUNT..=LARGEST_AGENT_COUNT
}

pub fn candidate_count(agent_count: u128) -> usize {
    list_candidate_connections(agent_count).len()
}
