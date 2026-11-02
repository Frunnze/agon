use orchestration_api::work::RunEvent;
use orchestration_core::identifiers::RunId;
use orchestration_core::run::{RunFailure, StepStatus};

use crate::run_events::{post_run_events, step_status_changed};
use crate::runner_log::log_report_failure;
use crate::runner_server::RunnerServer;

const RETRY_RUNS_ON_SAME_RUNNER: bool = true;

pub(crate) async fn report_step_failure<S: RunnerServer>(
    server: &S,
    run_id: RunId,
    failed_step: &str,
    reason: &str,
) {
    let events = vec![
        step_status_changed(failed_step, StepStatus::Failed),
        RunEvent::Failed {
            failure: RunFailure {
                step_name: failed_step.to_string(),
                runner: None,
                reason: reason.to_string(),
                retry_runs_on_same_runner: RETRY_RUNS_ON_SAME_RUNNER,
            },
        },
    ];

    if let Err(problem) = post_run_events(server, run_id, events).await {
        log_report_failure(run_id, &problem);
    }
}
