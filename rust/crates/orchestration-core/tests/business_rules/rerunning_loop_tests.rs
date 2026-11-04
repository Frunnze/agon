use std::collections::BTreeSet;

use chrono::DateTime;
use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::run::{Run, StepStatus};
use orchestration_core::run_routing::advance_after_step;
use orchestration_core::workflow::{AgentConnection, Workflow};
use orchestration_core::workflow_graph::loops_rerunning_agent;
use proptest::prelude::*;

use crate::branching_strategies::{branching_plan, build_branching_workflow};
use crate::routing_fixtures::{fresh_run, step_named};

fn finished_run_taking(
    workflow: &Workflow,
    taken_loop: &AgentConnection,
) -> Run {
    let mut run = fresh_run(workflow);
    for step in &mut run.steps {
        step.status = StepStatus::Done;
        step.result = Some(format!("result of {}", step.name));
        if step.agent_id == Some(taken_loop.from) {
            step.outcome.clone_from(&taken_loop.condition);
        }
    }
    run
}

fn agents_with_an_earlier_round(run: &Run) -> BTreeSet<WorkflowAgentId> {
    let mut rerun_agents = BTreeSet::new();
    for step in &run.steps {
        let has_earlier_round = !step.earlier_rounds.is_empty();
        if let (true, Some(agent_id)) = (has_earlier_round, step.agent_id) {
            rerun_agents.insert(agent_id);
        }
    }
    rerun_agents
}

fn agents_reporting_the_loop(
    workflow: &Workflow,
    taken_loop: &AgentConnection,
) -> BTreeSet<WorkflowAgentId> {
    let mut reporting_agents = BTreeSet::new();
    for agent in &workflow.agents {
        let rerunning_loops = loops_rerunning_agent(workflow, agent.id);
        if rerunning_loops.contains(&taken_loop) {
            reporting_agents.insert(agent.id);
        }
    }
    reporting_agents
}

proptest! {
    #[test]
    fn test_loops_rerunning_agent_property_names_the_loops_that_reset_it(
        plan in branching_plan(),
        chosen in any::<prop::sample::Index>(),
    ) {
        let workflow = build_branching_workflow(&plan);
        let loops: Vec<&AgentConnection> = workflow
            .connections
            .iter()
            .filter(|connection| connection.is_loop())
            .collect();
        if loops.is_empty() {
            for agent in &workflow.agents {
                let rerunning = loops_rerunning_agent(&workflow, agent.id);
                prop_assert!(rerunning.is_empty());
            }
            return Ok(());
        }
        let taken_loop = loops[chosen.index(loops.len())];
        let finished = finished_run_taking(&workflow, taken_loop);
        let source_name = finished
            .steps
            .iter()
            .find(|step| step.agent_id == Some(taken_loop.from))
            .map(|step| step.name.clone())
            .unwrap_or_default();

        let looped = advance_after_step(
            &finished,
            &workflow,
            &source_name,
            DateTime::UNIX_EPOCH,
        );

        let source_step = step_named(&looped, &source_name);
        prop_assert!(!source_step.earlier_rounds.is_empty());
        prop_assert_eq!(
            agents_with_an_earlier_round(&looped),
            agents_reporting_the_loop(&workflow, taken_loop)
        );
    }
}
