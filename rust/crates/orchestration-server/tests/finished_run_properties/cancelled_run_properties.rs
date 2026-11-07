use axum::http::StatusCode;
use orchestration_core::run::{RunStatus, StepStatus};
use orchestration_core::run_lifecycle::is_step_finished;
use proptest::prelude::*;

use crate::branching_fixtures::read_run;
use crate::finished_run_support::{
    WORK_STATUSES, cancel_run, cancel_while_asking,
};
use crate::test_client::{TestServer, block_on};

proptest! {
    #![proptest_config(ProptestConfig::with_cases(6))]

    #[test]
    fn test_cancel_run_record_property_every_skip_records_its_end(
        work_status in prop::sample::select(&WORK_STATUSES[..]),
    ) {
        let test = TestServer::start();

        let cancelled_run = block_on(cancel_while_asking(&test, work_status));

        let cancelled = &cancelled_run.cancelled;
        prop_assert_eq!(cancelled.status, RunStatus::Cancelled);
        prop_assert!(cancelled.finished_at.is_some());
        let pairs = cancelled_run.before.steps.iter().zip(&cancelled.steps);
        for (before, after) in pairs {
            if !is_step_finished(before.status) {
                prop_assert_eq!(after.status, StepStatus::Skipped);
                prop_assert_eq!(after.finished_at, cancelled.finished_at);
                prop_assert_eq!(after.started_at, before.started_at);
                prop_assert_eq!(&after.runner, &before.runner);
            }
        }
    }

    #[test]
    fn test_cancel_run_record_property_keeps_finished_steps(
        work_status in prop::sample::select(&WORK_STATUSES[..]),
    ) {
        let test = TestServer::start();

        let cancelled_run = block_on(cancel_while_asking(&test, work_status));

        let cancelled = &cancelled_run.cancelled;
        let pairs = cancelled_run.before.steps.iter().zip(&cancelled.steps);
        for (before, after) in pairs {
            if is_step_finished(before.status) {
                prop_assert_eq!(after, before);
            }
        }
    }

    #[test]
    fn test_cancel_run_record_property_a_finished_run_cannot_cancel_again(
        work_status in prop::sample::select(&WORK_STATUSES[..]),
    ) {
        let test = TestServer::start();

        let (cancelled, again_status, after) = block_on(async {
            let cancelled_run = cancel_while_asking(&test, work_status).await;
            let started = &cancelled_run.started;
            let owner = &started.account.owner;
            let again = cancel_run(&test, owner, &started.run).await;
            let after = read_run(&test, &started.account, &started.run).await;
            (cancelled_run.cancelled, again.status, after)
        });

        prop_assert_eq!(again_status, StatusCode::CONFLICT);
        prop_assert_eq!(after, cancelled);
    }
}
