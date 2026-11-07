use orchestration_core::run::{Run, StepStatus};
use orchestration_core::workflow::{AgentConnection, Workflow};
use proptest::prelude::*;
use proptest::sample::subsequence;

use crate::loop_support::{FORWARD_OUTCOME, LOOP_OUTCOME, step_name};
use crate::routing_fixtures::{
    connect, finish_step, fresh_run, routing_workflow, step_named,
};

const SMALLEST_AGENT_COUNT: u128 = 4;
const LARGEST_AGENT_COUNT: u128 = 7;
const LARGEST_TESTED_ROUND_LIMIT: u32 = 3;
const CHOSEN_STEP_COUNT: usize = 4;
const MOST_FINISHED_STEPS: usize = 400;

#[derive(Clone, Copy, Debug)]
pub struct LoopSpan {
    pub source: u128,
    pub target: u128,
    pub round_limit: u32,
}

#[derive(Clone, Copy, Debug)]
pub struct NestedPlan {
    pub agent_count: u128,
    pub inner: LoopSpan,
    pub outer: LoopSpan,
}

#[derive(Clone, Debug)]
pub struct NestedDrive {
    pub run: Run,
    pub inner_rounds_taken: u32,
    pub outer_rounds_taken: u32,
    pub unexpected_decisions: Vec<String>,
}

#[derive(Clone, Copy, Debug)]
struct LoopProgress {
    span: LoopSpan,
    rounds_this_pass: u32,
    rounds_taken: u32,
}

fn round_limit() -> impl Strategy<Value = u32> {
    1..=LARGEST_TESTED_ROUND_LIMIT
}

fn build_plan(
    agent_count: u128,
    chosen: &[u128],
    limits: (u32, u32),
) -> NestedPlan {
    let (inner_limit, outer_limit) = limits;
    NestedPlan {
        agent_count,
        inner: LoopSpan {
            source: chosen[2],
            target: chosen[1],
            round_limit: inner_limit,
        },
        outer: LoopSpan {
            source: chosen[3],
            target: chosen[0],
            round_limit: outer_limit,
        },
    }
}

pub fn nested_plan() -> impl Strategy<Value = NestedPlan> {
    (SMALLEST_AGENT_COUNT..=LARGEST_AGENT_COUNT)
        .prop_flat_map(|agent_count| {
            let numbers: Vec<u128> = (0..agent_count).collect();
            let chosen = subsequence(numbers, CHOSEN_STEP_COUNT);
            let limits = (round_limit(), round_limit());
            (Just(agent_count), chosen, limits)
        })
        .prop_map(|(agent_count, chosen, limits)| {
            build_plan(agent_count, &chosen, limits)
        })
}

pub fn same_target_plan() -> impl Strategy<Value = NestedPlan> {
    nested_plan().prop_map(|plan| NestedPlan {
        inner: LoopSpan {
            target: plan.outer.target,
            ..plan.inner
        },
        ..plan
    })
}

fn loop_connection(span: LoopSpan) -> AgentConnection {
    connect(
        span.source,
        span.target,
        Some(LOOP_OUTCOME),
        Some(span.round_limit),
    )
}

pub fn build_nested_workflow(plan: NestedPlan) -> Workflow {
    let mut connections = Vec::new();
    for number in 1..plan.agent_count {
        let from = number - 1;
        let is_loop_source =
            from == plan.inner.source || from == plan.outer.source;
        let condition = is_loop_source.then_some(FORWARD_OUTCOME);
        connections.push(connect(from, number, condition, None));
    }
    connections.push(loop_connection(plan.inner));
    connections.push(loop_connection(plan.outer));
    routing_workflow(plan.agent_count, connections)
}

fn find_next_step(run: &Run) -> Option<(u128, String)> {
    for step in &run.steps {
        let is_ready = step.status == StepStatus::Waiting;
        let number = step.agent_id.map(|agent_id| agent_id.0.as_u128());
        if let (true, Some(number)) = (is_ready, number) {
            return Some((number, step.name.clone()));
        }
    }
    None
}

fn is_round_started(run: &Run, span: LoopSpan) -> bool {
    let target = step_named(run, &step_name(span.target));
    let source_name = step_name(span.source);
    target.status == StepStatus::Waiting
        && target.loop_source.as_deref() == Some(source_name.as_str())
}

fn finish_loop_source(
    run: &Run,
    workflow: &Workflow,
    progress: &mut LoopProgress,
    unexpected_decisions: &mut Vec<String>,
) -> Run {
    let source_name = step_name(progress.span.source);
    let looped = finish_step(run, workflow, &source_name, Some(LOOP_OUTCOME));
    let is_taken = is_round_started(&looped, progress.span);
    let is_expected = progress.rounds_this_pass < progress.span.round_limit;
    if is_taken != is_expected {
        unexpected_decisions.push(format!(
            "{source_name}: taken {is_taken}, expected {is_expected} \
             after {} rounds this pass",
            progress.rounds_this_pass
        ));
    }
    if !is_taken {
        return finish_step(
            run,
            workflow,
            &source_name,
            Some(FORWARD_OUTCOME),
        );
    }
    progress.rounds_this_pass += 1;
    progress.rounds_taken += 1;
    looped
}

fn start_progress(span: LoopSpan) -> LoopProgress {
    LoopProgress {
        span,
        rounds_this_pass: 0,
        rounds_taken: 0,
    }
}

pub fn drive_nested_run(plan: NestedPlan) -> NestedDrive {
    let workflow = build_nested_workflow(plan);
    let mut run = fresh_run(&workflow);
    let mut inner = start_progress(plan.inner);
    let mut outer = start_progress(plan.outer);
    let mut unexpected_decisions = Vec::new();
    for _ in 0..MOST_FINISHED_STEPS {
        let Some((number, name)) = find_next_step(&run) else {
            break;
        };
        if number == plan.inner.source {
            let decisions = &mut unexpected_decisions;
            run = finish_loop_source(&run, &workflow, &mut inner, decisions);
        } else if number == plan.outer.source {
            let rounds_before = outer.rounds_taken;
            let decisions = &mut unexpected_decisions;
            run = finish_loop_source(&run, &workflow, &mut outer, decisions);
            if outer.rounds_taken > rounds_before {
                inner.rounds_this_pass = 0;
            }
        } else {
            run = finish_step(&run, &workflow, &name, None);
        }
    }
    NestedDrive {
        run,
        inner_rounds_taken: inner.rounds_taken,
        outer_rounds_taken: outer.rounds_taken,
        unexpected_decisions,
    }
}

pub fn loop_names(span: LoopSpan) -> (String, String) {
    (step_name(span.source), step_name(span.target))
}
