use chrono::{DateTime, Utc};
use orchestration_core::run::{Run, RunStep, StepStatus};
use orchestration_core::run_lifecycle::{apply_step_status, is_run_finished};
use proptest::option;
use proptest::prelude::*;

use crate::entity_strategies::{device_identifier, ordinary_timestamp};
use crate::run_fixtures::run_with_steps;
use crate::workflow_strategies::run_steps;

pub const FINAL_STEP_STATUSES: [StepStatus; 3] =
    [StepStatus::Done, StepStatus::Failed, StepStatus::Skipped];
pub const OPEN_STEP_STATUSES: [StepStatus; 4] = [
    StepStatus::Waiting,
    StepStatus::Running,
    StepStatus::WaitingForApproval,
    StepStatus::WaitingForPerson,
];

pub fn unfinished_run() -> impl Strategy<Value = Run> {
    run_steps()
        .prop_map(run_with_steps)
        .prop_filter("unfinished with steps", |run| {
            !run.steps.is_empty() && !is_run_finished(run.status)
        })
}

pub fn chosen_step_name(run: &Run, choice: prop::sample::Index) -> String {
    let index = choice.index(run.steps.len());
    run.steps[index].name.clone()
}

pub fn recorded_step() -> impl Strategy<Value = RunStep> {
    (
        option::of(device_identifier()),
        option::of(any::<String>()),
        option::of(any::<String>()),
        option::of(any::<String>()),
        option::of(ordinary_timestamp()),
    )
        .prop_map(|(runner, result, outcome, loop_source, started_at)| {
            RunStep {
                name: "review".to_owned(),
                agent_id: None,
                runner,
                status: StepStatus::Waiting,
                started_at,
                finished_at: None,
                result,
                outcome,
                loop_source,
                earlier_rounds: Vec::new(),
            }
        })
}

pub fn apply_to_single_step(
    step: &RunStep,
    status: StepStatus,
    at: DateTime<Utc>,
) -> Option<RunStep> {
    let run = run_with_steps(vec![step.clone()]);
    let changed = apply_step_status(&run, &step.name, status, at).ok()?;
    changed.steps.into_iter().next()
}
