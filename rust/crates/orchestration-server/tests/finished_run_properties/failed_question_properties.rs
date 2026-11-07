use axum::http::StatusCode;
use orchestration_core::run::{Run, RunStatus, StepStatus};
use proptest::prelude::*;

use crate::branching_fixtures::{answer_step, find_step, read_run};
use crate::finished_run_support::{
    LOOP_ANSWER, QUESTION_STEP, fail_beside_question, list_open_steps,
    restart_with_question_still_open,
};
use crate::test_client::{TestServer, block_on};

const REASON_PATTERN: &str = "[a-z ]{1,30}";
const ANSWERS: [&str; 2] = [LOOP_ANSWER, "approved"];

proptest! {
    #![proptest_config(ProptestConfig::with_cases(4))]

    #[test]
    fn test_apply_step_status_property_a_failure_skips_the_open_question(
        reason in REASON_PATTERN,
    ) {
        let test = TestServer::start();

        let failed = block_on(fail_beside_question(&test, &reason)).failed;

        prop_assert_eq!(failed.status, RunStatus::Failed);
        let question = find_step(&failed, QUESTION_STEP);
        prop_assert_eq!(question.status, StepStatus::Skipped);
        prop_assert_eq!(question.finished_at, failed.finished_at);
        let ship = find_step(&failed, "ship");
        prop_assert_eq!(ship.status, StepStatus::Skipped);
    }

    #[test]
    fn test_list_open_steps_property_a_failed_run_asks_nothing(
        reason in REASON_PATTERN,
    ) {
        let test = TestServer::start();

        let (failed, open_now, open_from_old_record) = block_on(async {
            let failed_question = fail_beside_question(&test, &reason).await;
            let owner = &failed_question.started.account.owner;
            let open_now = list_open_steps(&test, owner).await;
            let restarted = restart_with_question_still_open(
                &test,
                &failed_question.failed,
            );
            let open_from_old_record =
                list_open_steps(&restarted, owner).await;
            (failed_question.failed, open_now, open_from_old_record)
        });

        for open_steps in [open_now, open_from_old_record] {
            let asks_about_failed_run = open_steps
                .iter()
                .any(|open_step| open_step.run_id == failed.id);
            prop_assert!(!asks_about_failed_run, "{:?}", open_steps);
        }
    }

    #[test]
    fn test_record_person_answer_property_a_failed_run_refuses_answers(
        reason in REASON_PATTERN,
        answer in prop::sample::select(&ANSWERS[..]),
    ) {
        let test = TestServer::start();

        let (failed, answered_statuses, after) = block_on(async {
            let failed_question = fail_beside_question(&test, &reason).await;
            let started = &failed_question.started;
            let owner = &started.account.owner;
            let restarted = restart_with_question_still_open(
                &test,
                &failed_question.failed,
            );
            let mut answered_statuses = Vec::new();
            for server in [&test, &restarted] {
                let response = answer_step(
                    server,
                    owner,
                    &started.run,
                    QUESTION_STEP,
                    answer,
                )
                .await;
                answered_statuses.push(response.status);
            }
            let after: Run =
                read_run(&restarted, &started.account, &started.run).await;
            (failed_question.failed, answered_statuses, after)
        });

        for status in answered_statuses {
            prop_assert_eq!(status, StatusCode::CONFLICT);
        }
        prop_assert_eq!(after.status, RunStatus::Failed);
        prop_assert!(after.loop_rounds.is_empty());
        prop_assert_eq!(after.finished_at, failed.finished_at);
        for step in &after.steps {
            prop_assert_ne!(step.status, StepStatus::Waiting);
        }
    }
}
