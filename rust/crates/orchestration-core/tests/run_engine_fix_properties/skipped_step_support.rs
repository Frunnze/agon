use chrono::{DateTime, Utc};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::run::{Run, RunStatus, RunStep, StepStatus};
use orchestration_core::run_lifecycle::{is_run_finished, is_step_finished};
use proptest::collection::vec;
use proptest::option;
use proptest::prelude::*;

use crate::entity_strategies::{device_identifier, ordinary_timestamp};
use crate::run_fixtures::run_with_steps;
use crate::workflow_strategies::step_status;

const MAXIMUM_STEPS: usize = 7;

pub const OPEN_STEP_STATUSES: [StepStatus; 4] = [
    StepStatus::Waiting,
    StepStatus::Running,
    StepStatus::WaitingForApproval,
    StepStatus::WaitingForPerson,
];

pub const ALL_RUN_STATUSES: [RunStatus; 6] = [
    RunStatus::Queued,
    RunStatus::Running,
    RunStatus::WaitingForApproval,
    RunStatus::Failed,
    RunStatus::Cancelled,
    RunStatus::Done,
];

type StepParts = (
    StepStatus,
    Option<DeviceId>,
    Option<DateTime<Utc>>,
    Option<String>,
    DateTime<Utc>,
);

fn step_parts() -> impl Strategy<Value = StepParts> {
    (
        step_status(),
        option::of(device_identifier()),
        option::of(ordinary_timestamp()),
        option::of("[a-z ]{0,12}"),
        ordinary_timestamp(),
    )
}

fn build_step(index: usize, parts: StepParts) -> RunStep {
    let (status, runner, started_at, result, earlier_end) = parts;
    let finished_at = is_step_finished(status).then_some(earlier_end);
    RunStep {
        name: format!("step-{index}"),
        agent_id: None,
        runner,
        status,
        started_at,
        finished_at,
        result,
        outcome: None,
        loop_source: None,
        earlier_rounds: Vec::new(),
    }
}

pub fn scattered_steps() -> impl Strategy<Value = Vec<RunStep>> {
    vec(step_parts(), 0..MAXIMUM_STEPS).prop_map(|all_parts| {
        let mut steps = Vec::new();
        for (index, parts) in all_parts.into_iter().enumerate() {
            steps.push(build_step(index, parts));
        }
        steps
    })
}

pub fn unfinished_scattered_run() -> impl Strategy<Value = Run> {
    scattered_steps()
        .prop_map(run_with_steps)
        .prop_filter("an unfinished run with steps", |run| {
            !run.steps.is_empty() && !is_run_finished(run.status)
        })
}

pub fn choose_step_name(run: &Run, choice: prop::sample::Index) -> String {
    let index = choice.index(run.steps.len());
    run.steps[index].name.clone()
}

pub fn is_step_open(status: StepStatus) -> bool {
    OPEN_STEP_STATUSES.contains(&status)
}
