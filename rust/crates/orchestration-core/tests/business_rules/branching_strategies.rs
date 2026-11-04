use std::collections::BTreeSet;
use std::ops::RangeInclusive;

use orchestration_core::workflow::{
    AgentConnection, StepKind, Workflow, WorkflowAgent,
};
use orchestration_core::workflow_graph::forward_reachable_agents;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::routing_fixtures::{connect, routing_workflow};
use crate::workflow_strategies::{
    acyclic_workflow_with_agent_counts, workflow_from_parts,
};

const SMALLEST_BRANCHING_AGENT_COUNT: usize = 2;
const MAXIMUM_BRANCHING_AGENTS: usize = 6;
const MAXIMUM_LOOPS: usize = 3;
const SMALLEST_ROUND_LIMIT: u32 = 1;
const LARGEST_ROUND_LIMIT: u32 = 10;
const LARGEST_BRANCH_STEP_COUNT: usize = 3;
const SMALLEST_BRANCH_COUNT_PER_FORK: usize = 2;
const LARGEST_BRANCH_COUNT_PER_FORK: usize = 3;
const NESTED_FORK_DEPTH: u32 = 2;
const LARGEST_NESTED_PLAN_SIZE: u32 = 16;
const EXPECTED_BRANCHES_PER_FORK: u32 = 3;

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

#[derive(Clone, Debug)]
struct ForkPlan {
    branches: Vec<BranchPlan>,
    do_branches_join: bool,
}

#[derive(Clone, Debug)]
struct BranchPlan {
    step_count: usize,
    inner_fork: Option<ForkPlan>,
}

#[derive(Default)]
struct ForkWorkflowBuilder {
    step_count: u128,
    connections: Vec<AgentConnection>,
}

impl ForkWorkflowBuilder {
    fn add_step(
        &mut self,
        upstream_steps: &[u128],
        outcome: Option<&str>,
    ) -> u128 {
        let step = self.step_count;
        self.step_count += 1;
        for upstream_step in upstream_steps {
            let connection = connect(*upstream_step, step, outcome, None);
            self.connections.push(connection);
        }
        step
    }

    fn add_branch(
        &mut self,
        upstream_steps: &[u128],
        outcome: Option<&str>,
        plan: &BranchPlan,
    ) -> Vec<u128> {
        let mut last_step = self.add_step(upstream_steps, outcome);
        for _ in 1..plan.step_count {
            last_step = self.add_step(&[last_step], None);
        }
        let Some(fork) = &plan.inner_fork else {
            return vec![last_step];
        };

        let mut exits = Vec::new();
        for (position, branch) in fork.branches.iter().enumerate() {
            let branch_outcome = format!("branch {position}");
            let branch_exits =
                self.add_branch(&[last_step], Some(&branch_outcome), branch);
            exits.extend(branch_exits);
        }

        if fork.do_branches_join {
            return vec![self.add_step(&exits, None)];
        }
        exits
    }
}

fn branch_plan() -> impl Strategy<Value = BranchPlan> {
    let plain_branch =
        (1..=LARGEST_BRANCH_STEP_COUNT).prop_map(|step_count| BranchPlan {
            step_count,
            inner_fork: None,
        });
    plain_branch.prop_recursive(
        NESTED_FORK_DEPTH,
        LARGEST_NESTED_PLAN_SIZE,
        EXPECTED_BRANCHES_PER_FORK,
        |inner_branch| {
            (1..=LARGEST_BRANCH_STEP_COUNT, fork_plan(inner_branch)).prop_map(
                |(step_count, inner_fork)| BranchPlan {
                    step_count,
                    inner_fork: Some(inner_fork),
                },
            )
        },
    )
}

fn fork_plan(
    branch: impl Strategy<Value = BranchPlan>,
) -> impl Strategy<Value = ForkPlan> {
    let branch_counts =
        SMALLEST_BRANCH_COUNT_PER_FORK..=LARGEST_BRANCH_COUNT_PER_FORK;
    (vec(branch, branch_counts), any::<bool>()).prop_map(
        |(branches, do_branches_join)| ForkPlan {
            branches,
            do_branches_join,
        },
    )
}

fn build_fork_workflow(plan: &BranchPlan) -> Workflow {
    let mut builder = ForkWorkflowBuilder::default();
    builder.add_branch(&[], None, plan);
    routing_workflow(builder.step_count, builder.connections)
}

pub fn shuffled_fork_workflow() -> impl Strategy<Value = Workflow> {
    (1..=LARGEST_BRANCH_STEP_COUNT, fork_plan(branch_plan()))
        .prop_map(|(step_count, fork)| {
            build_fork_workflow(&BranchPlan {
                step_count,
                inner_fork: Some(fork),
            })
        })
        .prop_flat_map(|workflow| {
            (
                Just(workflow.agents).prop_shuffle(),
                Just(workflow.connections).prop_shuffle(),
            )
        })
        .prop_map(|(agents, connections)| {
            workflow_from_parts(agents, connections)
        })
}
