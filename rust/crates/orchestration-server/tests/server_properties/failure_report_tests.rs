use axum::http::StatusCode;
use orchestration_api::work::RunEvent;
use orchestration_core::identifiers::DeviceId;
use orchestration_core::run::{RunFailure, RunStatus, StepStatus};
use proptest::prelude::*;

use crate::run_fixtures::{post_events, start_claimed_run};
use crate::test_client::{TestServer, block_on};

const REPORT_CASES: u32 = 8;
const REASON_PATTERN: &str = "[a-z ]{1,40}";
const CLAIMED_RUNNER_PATTERN: &str = "[a-f0-9]{32}";

fn step_status_event(step_name: &str, status: StepStatus) -> RunEvent {
    RunEvent::StepStatusChanged {
        step_name: step_name.to_owned(),
        status,
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REPORT_CASES))]

    #[test]
    fn test_post_run_events_property_the_runners_failure_report_is_kept(
        reason in REASON_PATTERN,
        claimed_runner in proptest::option::of(CLAIMED_RUNNER_PATTERN),
    ) {
        let test = TestServer::start();
        let (running_status, report_status, failed_run, holder_id) =
            block_on(async {
            let claimed = start_claimed_run(&test).await;
            let step_name = claimed.run.steps[0].name.clone();
            let running =
                vec![step_status_event(&step_name, StepStatus::Running)];
            let (running_status, _running_run) =
                post_events(&test, &claimed.holder, &claimed.run, running)
                    .await;
            let failure = RunFailure {
                step_name: step_name.clone(),
                runner: claimed_runner.map(DeviceId),
                reason: reason.clone(),
                retry_runs_on_same_runner: true,
            };
            let report = vec![
                step_status_event(&step_name, StepStatus::Failed),
                RunEvent::Failed { failure },
            ];
            let (report_status, failed_run) =
                post_events(&test, &claimed.holder, &claimed.run, report)
                    .await;
            let holder_id = claimed.holder.device_id();
            (running_status, report_status, failed_run, holder_id)
        });

        prop_assert_eq!(running_status, StatusCode::OK);
        prop_assert_eq!(report_status, StatusCode::OK);
        let failed_run = failed_run.expect("the report is stored");
        prop_assert_eq!(failed_run.status, RunStatus::Failed);
        prop_assert_eq!(failed_run.steps[0].status, StepStatus::Failed);
        let failure = failed_run.failure.expect("the failure is stored");
        prop_assert_eq!(failure.reason, reason);
        prop_assert_eq!(failure.runner, Some(holder_id));
    }
}
