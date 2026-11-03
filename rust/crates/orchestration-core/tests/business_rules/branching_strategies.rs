use std::collections::BTreeSet;
use std::ops::RangeInclusive;

use orchestration_core::workflow::{
    AgentConnection, StepKind, Workflow, WorkflowAgent,
};
use orchestration_core::workflow_graph::forward_reachable_agents;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::workflow_strategies::{
    acyclic_workflow_with_agent_counts, workflow_from_parts,
};

const SMALLEST_BRANCHING_AGENT_COUNT: usize = 2;
const MAXIMUM_BRANCHING_AGENTS: usize = 6;
const MAXIMUM_LOOPS: usize = 3;
const SMALLEST_ROUND_LIMIT: u32 = 1;
const LARGEST_ROUND_LIMIT: u32 = 10;

#[derive(Clone, Debug)]
pub struct BranchingPlan {
    pub workflow: Workflow,
    pub conditioned: Vec<bool>,
    pub person_steps: Vec<bool>,
    pub loop_picks: Vec<(prop::sample::Index, u32)>,
}

pub fn outcome_name(
    source_position: usize,
    outgoing_position: usize,
) -> String {
    format!("outcome {source_position}-{outgoing_position}")
}

pub fn branching_plan() -> impl Strategy<Value = BranchingPlan> {
    branching_plan_with_agent_counts(
        SMALLEST_BRANCHING_AGENT_COUNT..=MAXIMUM_BRANCHING_AGENTS,
    )
}

pub fn branching_plan_with_agent_counts(
    agent_counts: RangeInclusive<usize>,
) -> impl Strategy<Value = BranchingPlan> {
    acyclic_workflow_with_agent_counts(agent_counts)
        .prop_flat_map(|workflow| {
            let connection_count = workflow.connections.len();
            let agent_count = workflow.agents.len();
            (
                Just(workflow),
                vec(any::<bool>(), connection_count),
                vec(any::<bool>(), agent_count),
                vec(
                    (
                        any::<prop::sample::Index>(),
                        SMALLEST_ROUND_LIMIT..=LARGEST_ROUND_LIMIT,
                    ),
                    0..=MAXIMUM_LOOPS,
                ),
            )
        })
        .prop_map(|(workflow, conditioned, person_steps, loop_picks)| {
            BranchingPlan {
                workflow,
                conditioned,
                person_steps,
                loop_picks,
            }
        })
}

pub fn build_branching_workflow(plan: &BranchingPlan) -> Workflow {
    let agents = mark_person_steps(&plan.workflow.agents, &plan.person_steps);
    let mut outgoing_counts = vec![0_usize; agents.len()];
    let mut connections = Vec::new();
    for (connection, is_conditioned) in
        plan.workflow.connections.iter().zip(&plan.conditioned)
    {
        let source_position = position_of(&agents, connection);
        let condition = is_conditioned
            .then(|| next_outcome(&mut outgoing_counts, source_position));
        connections.push(AgentConnection {
            condition,
            ..connection.clone()
        });
    }
    let forward = workflow_from_parts(agents.clone(), connections.clone());
    let back_pairs = list_back_pairs(&forward);
    let mut used_pairs = BTreeSet::new();
    for (pick, round_limit) in &plan.loop_picks {
        if back_pairs.is_empty() {
            break;
        }
        let (from_position, to_position) =
            back_pairs[pick.index(back_pairs.len())];
        if !used_pairs.insert((from_position, to_position)) {
            continue;
        }
        connections.push(AgentConnection {
            from: agents[from_position].id,
            to: agents[to_position].id,
            condition: Some(next_outcome(&mut outgoing_counts, from_position)),
            round_limit: Some(*round_limit),
        });
    }
    workflow_from_parts(agents, connections)
}

pub fn list_back_pairs(workflow: &Workflow) -> Vec<(usize, usize)> {
    let mut pairs = Vec::new();
    for (to_position, target) in workflow.agents.iter().enumerate() {
        let reached = forward_reachable_agents(workflow, target.id);
        for (from_position, source) in workflow.agents.iter().enumerate() {
            if from_position != to_position && reached.contains(&source.id) {
                pairs.push((from_position, to_position));
            }
        }
    }
    pairs
}

fn mark_person_steps(
    agents: &[WorkflowAgent],
    person_steps: &[bool],
) -> Vec<WorkflowAgent> {
    let mut marked = Vec::new();
    for (agent, is_person) in agents.iter().zip(person_steps) {
        let step_kind = if *is_person {
            StepKind::Person
        } else {
            StepKind::Agent
        };
        marked.push(WorkflowAgent {
            step_kind,
            ..agent.clone()
        });
    }
    marked
}

fn position_of(
    agents: &[WorkflowAgent],
    connection: &AgentConnection,
) -> usize {
    agents
        .iter()
        .position(|agent| agent.id == connection.from)
        .unwrap_or_default()
}

fn next_outcome(
    outgoing_counts: &mut [usize],
    source_position: usize,
) -> String {
    let outgoing_position = outgoing_counts[source_position];
    outgoing_counts[source_position] += 1;
    outcome_name(source_position, outgoing_position)
}
