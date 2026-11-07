use std::collections::BTreeSet;
use std::ops::RangeInclusive;

use crate::identifiers::WorkflowAgentId;
use crate::workflow::{AgentConnection, Workflow};
use crate::workflow_graph::{
    WorkflowProblem, find_agent_by_id, forward_reachable_agents,
};

pub const MAXIMUM_CONDITION_LENGTH: usize = 40;
pub const ROUND_LIMITS: RangeInclusive<u32> = 1..=10;
const CONDITION_SPACE: char = ' ';
const CONDITION_DASH: char = '-';

pub(crate) fn validate_conditions(
    workflow: &Workflow,
) -> Result<(), WorkflowProblem> {
    let mut seen_outcomes: BTreeSet<(WorkflowAgentId, &str)> = BTreeSet::new();
    for connection in &workflow.connections {
        validate_round_limit(connection)?;
        let Some(condition) = &connection.condition else {
            continue;
        };
        if !is_well_formed_condition(condition) {
            return Err(WorkflowProblem::InvalidCondition {
                condition: condition.clone(),
            });
        }
        if !seen_outcomes.insert((connection.from, condition.as_str())) {
            return Err(WorkflowProblem::DuplicateCondition {
                step_name: name_agent(workflow, connection.from),
                condition: condition.clone(),
            });
        }
    }
    Ok(())
}

pub(crate) fn validate_distinct_step_pairs(
    workflow: &Workflow,
) -> Result<(), WorkflowProblem> {
    let mut seen_pairs: BTreeSet<(WorkflowAgentId, WorkflowAgentId)> =
        BTreeSet::new();
    for connection in &workflow.connections {
        if !seen_pairs.insert((connection.from, connection.to)) {
            return Err(WorkflowProblem::RepeatedConnection {
                from: name_agent(workflow, connection.from),
                to: name_agent(workflow, connection.to),
            });
        }
    }
    Ok(())
}

pub(crate) fn validate_loops(
    workflow: &Workflow,
) -> Result<(), WorkflowProblem> {
    for connection in &workflow.connections {
        if !connection.is_loop() {
            continue;
        }
        let reached_from_target =
            forward_reachable_agents(workflow, connection.to);
        if !reached_from_target.contains(&connection.from) {
            return Err(WorkflowProblem::LoopPointsForward {
                from: name_agent(workflow, connection.from),
                to: name_agent(workflow, connection.to),
            });
        }
    }
    Ok(())
}

fn validate_round_limit(
    connection: &AgentConnection,
) -> Result<(), WorkflowProblem> {
    let Some(round_limit) = connection.round_limit else {
        return Ok(());
    };
    if !ROUND_LIMITS.contains(&round_limit) {
        return Err(WorkflowProblem::InvalidRoundLimit { round_limit });
    }
    if connection.condition.is_none() {
        return Err(WorkflowProblem::LoopWithoutCondition);
    }
    Ok(())
}

fn is_well_formed_condition(condition: &str) -> bool {
    let length = condition.chars().count();
    let has_allowed_length = (1..=MAXIMUM_CONDITION_LENGTH).contains(&length);
    let has_allowed_characters = condition.chars().all(|character| {
        character.is_ascii_lowercase()
            || character.is_ascii_digit()
            || character == CONDITION_SPACE
            || character == CONDITION_DASH
    });
    let is_trimmed = condition.trim() == condition;
    has_allowed_length && has_allowed_characters && is_trimmed
}

fn name_agent(workflow: &Workflow, agent_id: WorkflowAgentId) -> String {
    find_agent_by_id(workflow, agent_id)
        .map_or_else(|| agent_id.0.to_string(), |agent| agent.name.clone())
}
