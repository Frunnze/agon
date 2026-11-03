use chrono::DateTime;
use orchestration_core::device::RunnerLink;
use orchestration_core::identifiers::{DeviceId, RunId, TaskId};
use orchestration_core::run::{Run, RunStatus, RunStep};
use orchestration_core::run_lifecycle::derive_run_status;
use uuid::Uuid;

pub const RUN_NUMBER: u32 = 42;

pub fn run_identifier() -> RunId {
    RunId(Uuid::from_u128(1))
}

pub fn starter() -> DeviceId {
    DeviceId("air-laptop".to_owned())
}

pub fn run_with_steps(steps: Vec<RunStep>) -> Run {
    Run {
        id: run_identifier(),
        task_id: TaskId(Uuid::nil()),
        number: RUN_NUMBER,
        status: derive_run_status(&steps),
        steps,
        log: Vec::new(),
        chat: Vec::new(),
        failure: None,
        link: RunnerLink::Direct,
        link_lost_at: None,
        agent_session: None,
        worktree_branch: None,
        started_by: starter(),
        started_at: DateTime::UNIX_EPOCH,
        finished_at: None,
        loop_rounds: Vec::new(),
        notes: Vec::new(),
    }
}

pub fn is_run_finished(status: RunStatus) -> bool {
    matches!(
        status,
        RunStatus::Done | RunStatus::Failed | RunStatus::Cancelled
    )
}
