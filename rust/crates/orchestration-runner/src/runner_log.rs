use orchestration_core::identifiers::RunId;
use orchestration_hub::keep_awake::KeepAwakeError;
use tokio::task::JoinError;
use tracing::warn;

use crate::runner_server::ServerError;

pub(crate) fn log_heartbeat_failure(problem: &ServerError) {
    warn!(%problem, "could not send the runner heartbeat");
}

pub(crate) fn log_cache_listing_failure(problem: &std::io::Error) {
    warn!(%problem, "could not list the cached repositories");
}

pub(crate) fn log_claim_failure(problem: &ServerError) {
    warn!(%problem, "could not claim the next run");
}

pub(crate) fn log_cancellation_check_failure(
    run_id: RunId,
    problem: &ServerError,
) {
    warn!(run = %run_id.0, %problem, "could not check for cancellation");
}

pub(crate) fn log_report_failure(run_id: RunId, problem: &ServerError) {
    warn!(run = %run_id.0, %problem, "could not report the run result");
}

pub(crate) fn log_run_task_failure(problem: &JoinError) {
    warn!(%problem, "a run stopped unexpectedly");
}

pub(crate) fn log_sleep_prevention_unavailable(problem: &KeepAwakeError) {
    warn!(%problem, "the run goes on without keeping the computer awake");
}
