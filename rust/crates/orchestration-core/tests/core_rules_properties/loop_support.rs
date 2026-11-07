use orchestration_core::run::Run;
use orchestration_core::workflow::{AgentConnection, Workflow, WorkflowAgent};
use proptest::prelude::*;

use crate::routing_fixtures::{connect, finish_step, routing_workflow};
use crate::workflow_strategies::{agent_identifier, workflow_from_parts};

pub const LOOP_OUTCOME: &str = "again";
pub const FORWARD_OUTCOME: &str = "done";
const SMALLEST_LOOP_AGENT_COUNT: u128 = 2;
const LARGEST_LOOP_AGENT_COUNT: u128 = 6;
const SMALLEST_ROUND_LIMIT: u32 = 1;
const LARGEST_ROUND_LIMIT: u32 = 10;

#[derive(Clone, Copy, Debug)]
pub struct LoopPlan {
    pub agent_count: u128,
    pub source: u128,
    pub target: u128,
    pub round_limit: u32,
}

pub fn loop_plan() -> impl Strategy<Value = LoopPlan> {
    (SMALLEST_LOOP_AGENT_COUNT..=LARGEST_LOOP_AGENT_COUNT)
        .prop_flat_map(|agent_count| (Just(agent_count), 1..agent_count))
        .prop_flat_map(|(agent_count, source)| {
            (
                Just(agent_count),
                Just(source),
                0..source,
                SMALLEST_ROUND_LIMIT..=LARGEST_ROUND_LIMIT,
            )
        })
        .prop_map(|(agent_count, source, target, round_limit)| LoopPlan {
            agent_count,
            source,
            target,
            round_limit,
        })
}

pub fn step_name(number: u128) -> String {
    format!("step-{number}")
}

fn chain_connections(agent_count: u128) -> Vec<AgentConnection> {
    let mut connections = Vec::new();
    for number in 1..agent_count {
        connections.push(connect(number - 1, number, None, None));
    }
    connections
}

pub fn chain_workflow(
    agent_count: u128,
    extra_connections: Vec<AgentConnection>,
) -> Workflow {
    let mut connections = chain_connections(agent_count);
    connections.extend(extra_connections);
    routing_workflow(agent_count, connections)
}

pub fn build_loop_workflow(plan: LoopPlan) -> Workflow {
    let mut connections = Vec::new();
    for number in 1..plan.agent_count {
        let from = number - 1;
        let condition = (from == plan.source).then_some(FORWARD_OUTCOME);
        connections.push(connect(from, number, condition, None));
    }
    connections.push(connect(
        plan.source,
        plan.target,
        Some(LOOP_OUTCOME),
        Some(plan.round_limit),
    ));
    routing_workflow(plan.agent_count, connections)
}

pub fn rename_agents(workflow: &Workflow, names: &[String]) -> Workflow {
    let mut agents = Vec::new();
    for (agent, name) in workflow.agents.iter().zip(names) {
        agents.push(WorkflowAgent {
            name: name.clone(),
            ..agent.clone()
        });
    }
    workflow_from_parts(agents, workflow.connections.clone())
}

pub fn name_in_run(run: &Run, number: u128) -> Option<String> {
    let agent_id = agent_identifier(number);
    run.steps
        .iter()
        .find(|step| step.agent_id == Some(agent_id))
        .map(|step| step.name.clone())
}

pub fn count_loop_rounds(run: &Run, from: &str, to: &str) -> u32 {
    let mut rounds = 0;
    for loop_rounds in &run.loop_rounds {
        if loop_rounds.from == from && loop_rounds.to == to {
            rounds += loop_rounds.rounds;
        }
    }
    rounds
}

pub fn finish_round(
    run: &Run,
    workflow: &Workflow,
    plan: LoopPlan,
    first_step: u128,
) -> Run {
    let mut advanced = run.clone();
    for number in first_step..plan.source {
        if let Some(name) = name_in_run(&advanced, number) {
            advanced = finish_step(&advanced, workflow, &name, None);
        }
    }
    let source_name = name_in_run(&advanced, plan.source).unwrap_or_default();
    finish_step(&advanced, workflow, &source_name, Some(LOOP_OUTCOME))
}
