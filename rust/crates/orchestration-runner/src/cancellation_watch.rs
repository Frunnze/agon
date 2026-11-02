use std::time::Duration;

use orchestration_core::identifiers::RunId;

use crate::runner_log::log_cancellation_check_failure;
use crate::runner_server::RunnerServer;
use crate::steady_interval::steady_interval;

pub(crate) async fn wait_until_cancelled<S: RunnerServer>(
    server: &S,
    run_id: RunId,
    check_interval: Duration,
) {
    let mut timer = steady_interval(check_interval);
    loop {
        timer.tick().await;
        match server.is_run_cancelled(run_id).await {
            Ok(true) => return,
            Ok(false) => {}
            Err(problem) => log_cancellation_check_failure(run_id, &problem),
        }
    }
}
