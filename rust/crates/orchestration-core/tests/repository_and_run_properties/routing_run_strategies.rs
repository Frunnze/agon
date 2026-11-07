use orchestration_core::identifiers::DeviceId;
use orchestration_core::run::{Run, RunStep, StepStatus};
use orchestration_core::step_outcomes::list_step_choices;
use orchestration_core::workflow::Workflow;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::branching_strategies::{branching_plan, build_branching_workflow};
use crate::routing_fixtures::fresh_run;
use crate::run_fixtures::run_with_steps;
use crate::workflow_strategies::step_status;

pub const CLAIMING_RUNNER: &str = "claiming-runner";

#[derive(Clone, Debug)]
pub struct StepScatter {
    pub status: StepStatus,
    pub outcome_pick: prop::sample::Index,
    pub is_claimed: bool,
}

#[derive(Clone, Debug)]
pub struct RoutedRun {
    pub workflow: Workflow,
    pub run: Run,
}

fn step_scatter() -> impl Strategy<Value = StepScatter> {
    (step_status(), any::<prop::sample::Index>(), any::<bool>()).prop_map(
        |(status, outcome_pick, is_claimed)| StepScatter {
            status,
            outcome_pick,
            is_claimed,
        },
    )
}

pub fn pick_outcome(
    workflow: &Workflow,
    step: &RunStep,
    outcome_pick: prop::sample::Index,
) -> Option<String> {
    let agent_id = step.agent_id?;
    let choices = list_step_choices(workflow, agent_id);
    let position = outcome_pick.index(choices.len() + 1);
    choices.get(position).cloned()
}

pub fn scatter_run(workflow: &Workflow, scatters: &[StepScatter]) -> Run {
    let fresh = fresh_run(workflow);
    let mut steps = Vec::new();
    for (step, scatter) in fresh.steps.iter().zip(scatters) {
        let runner = scatter
            .is_claimed
            .then(|| DeviceId(CLAIMING_RUNNER.to_owned()));
        steps.push(RunStep {
            status: scatter.status,
            outcome: pick_outcome(workflow, step, scatter.outcome_pick),
            runner,
            ..step.clone()
        });
    }
    run_with_steps(steps)
}

pub fn routed_run() -> impl Strategy<Value = RoutedRun> {
    branching_plan()
        .prop_flat_map(|plan| {
            let workflow = build_branching_workflow(&plan);
            let step_count = workflow.agents.len();
            (Just(workflow), vec(step_scatter(), step_count))
        })
        .prop_map(|(workflow, scatters)| {
            let run = scatter_run(&workflow, &scatters);
            RoutedRun { workflow, run }
        })
}

pub fn fresh_routed_run() -> impl Strategy<Value = RoutedRun> {
    branching_plan().prop_map(|plan| {
        let workflow = build_branching_workflow(&plan);
        let run = fresh_run(&workflow);
        RoutedRun { workflow, run }
    })
}
