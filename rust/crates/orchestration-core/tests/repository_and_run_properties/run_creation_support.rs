use chrono::{DateTime, Utc};
use orchestration_core::identifiers::WorkflowId;
use orchestration_core::run::Run;
use orchestration_core::run_lifecycle::{RunProblem, create_run};
use orchestration_core::task::Task;
use orchestration_core::workflow::Workflow;
use uuid::Uuid;

use crate::run_fixtures::{RUN_NUMBER, run_identifier, starter};

pub fn create_test_run(
    task: &Task,
    workflow: Option<&Workflow>,
    started_at: DateTime<Utc>,
) -> Result<Run, RunProblem> {
    create_run(
        task,
        workflow,
        RUN_NUMBER,
        run_identifier(),
        starter(),
        started_at,
    )
}

pub fn workflow_id_from(number: u128) -> WorkflowId {
    WorkflowId(Uuid::from_u128(number))
}
