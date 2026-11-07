use orchestration_api::work::{RunEvent, RunEventsRequest};
use orchestration_core::run::{RunFailure, StepStatus};
use orchestration_runner::runner_server::RunnerServer;
use proptest::prelude::*;

use crate::support::command_builders::prepare_workspace;
use crate::support::runner_access::{
    ClaimedRun, claim_started_task, started_task_command,
};
use crate::support::test_device::{describe, fail};

const TASK_DETAILS: &str = "task details only devices can read";
const READING_CASES: u32 = 3;
const OPEN_STEP_STATUSES: [StepStatus; 3] = [
    StepStatus::Running,
    StepStatus::WaitingForApproval,
    StepStatus::Waiting,
];

fn claim_a_run() -> Result<ClaimedRun, String> {
    let prepared = prepare_workspace()?;
    let task_command = started_task_command(&prepared, TASK_DETAILS);
    claim_started_task(prepared, &task_command)
}

fn post_events(
    claimed: &ClaimedRun,
    events: Vec<RunEvent>,
) -> Result<(), String> {
    let request = RunEventsRequest { events };
    let run_id = claimed.assignment.run.id;
    let posting = claimed.runner.post_run_events(run_id, &request);
    claimed.runtime.block_on(posting).map_err(describe)
}

fn read_whether_stopped(claimed: &ClaimedRun) -> Result<bool, String> {
    let run_id = claimed.assignment.run.id;
    let reading = claimed.runner.is_run_stopped(run_id);
    claimed.runtime.block_on(reading).map_err(describe)
}

fn status_event(claimed: &ClaimedRun, status: StepStatus) -> RunEvent {
    RunEvent::StepStatusChanged {
        step_name: claimed.assignment.step_name.clone(),
        status,
    }
}

fn failure_event(claimed: &ClaimedRun, reason: &str) -> RunEvent {
    RunEvent::Failed {
        failure: RunFailure {
            step_name: claimed.assignment.step_name.clone(),
            runner: None,
            reason: reason.to_owned(),
            retry_runs_on_same_runner: false,
        },
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(READING_CASES))]

    #[test]
    fn test_read_whether_stopped_property_a_failed_run_reads_as_stopped(
        reason in "[a-z ]{1,24}",
    ) {
        let claimed = claim_a_run().map_err(fail)?;
        let before = read_whether_stopped(&claimed).map_err(fail)?;

        let failure = vec![
            status_event(&claimed, StepStatus::Failed),
            failure_event(&claimed, &reason),
        ];
        post_events(&claimed, failure).map_err(fail)?;

        let after = read_whether_stopped(&claimed).map_err(fail)?;
        prop_assert!(!before);
        prop_assert!(after);
    }

    #[test]
    fn test_read_whether_stopped_property_open_steps_never_read_as_stopped(
        status in prop::sample::select(&OPEN_STEP_STATUSES[..]),
    ) {
        let claimed = claim_a_run().map_err(fail)?;

        let progress = vec![status_event(&claimed, status)];
        post_events(&claimed, progress).map_err(fail)?;

        let is_stopped = read_whether_stopped(&claimed).map_err(fail)?;
        prop_assert!(!is_stopped);
    }

    #[test]
    fn test_read_whether_stopped_property_a_done_run_is_not_stopped(
        is_started_first in any::<bool>(),
    ) {
        let claimed = claim_a_run().map_err(fail)?;
        let mut events = Vec::new();
        if is_started_first {
            events.push(status_event(&claimed, StepStatus::Running));
        }
        events.push(status_event(&claimed, StepStatus::Done));

        post_events(&claimed, events).map_err(fail)?;

        let is_stopped = read_whether_stopped(&claimed).map_err(fail)?;
        prop_assert!(!is_stopped);
    }
}
