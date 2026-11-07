use axum::http::StatusCode;
use orchestration_core::run::StepStatus;
use orchestration_core::run_lifecycle::is_run_finished;
use proptest::prelude::*;

use crate::branching_fixtures::{
    answer_step, claim_step, find_step, read_run,
};
use crate::finished_run_support::{
    LOOP_ANSWER, QUESTION_STEP, WORK_STATUSES, cancel_while_asking,
    list_open_steps, reach_question,
};
use crate::test_client::{TestServer, block_on};

const ANSWERS: [&str; 2] = [LOOP_ANSWER, "approved"];

proptest! {
    #![proptest_config(ProptestConfig::with_cases(4))]

    #[test]
    fn test_list_open_steps_property_a_running_run_still_asks(
        work_is_claimed in any::<bool>(),
    ) {
        let test = TestServer::start();

        let (run_id, open_steps) = block_on(async {
            let started = reach_question(&test).await;
            if work_is_claimed {
                claim_step(&test, &started.runners[0]).await;
            }
            let owner = &started.account.owner;
            let open_steps = list_open_steps(&test, owner).await;
            (started.run.id, open_steps)
        });

        let asked: Vec<&str> = open_steps
            .iter()
            .filter(|open_step| open_step.run_id == run_id)
            .map(|open_step| open_step.step_name.as_str())
            .collect();
        prop_assert_eq!(asked, vec![QUESTION_STEP]);
    }

    #[test]
    fn test_list_open_steps_property_a_cancelled_run_asks_nothing(
        work_status in prop::sample::select(&WORK_STATUSES[..]),
    ) {
        let test = TestServer::start();

        let (cancelled, open_steps) = block_on(async {
            let cancelled_run = cancel_while_asking(&test, work_status).await;
            let owner = &cancelled_run.started.account.owner;
            let open_steps = list_open_steps(&test, owner).await;
            (cancelled_run.cancelled, open_steps)
        });

        let asks_about_cancelled_run = open_steps
            .iter()
            .any(|open_step| open_step.run_id == cancelled.id);
        prop_assert!(!asks_about_cancelled_run);
    }

    #[test]
    fn test_record_person_answer_property_a_cancelled_run_refuses_answers(
        work_status in prop::sample::select(&WORK_STATUSES[..]),
        answer in prop::sample::select(&ANSWERS[..]),
    ) {
        let test = TestServer::start();

        let (cancelled, status, after) = block_on(async {
            let cancelled_run = cancel_while_asking(&test, work_status).await;
            let started = &cancelled_run.started;
            let owner = &started.account.owner;
            let response =
                answer_step(&test, owner, &started.run, QUESTION_STEP, answer)
                    .await;
            let after = read_run(&test, &started.account, &started.run).await;
            (cancelled_run.cancelled, response.status, after)
        });

        prop_assert_eq!(status, StatusCode::CONFLICT);
        prop_assert_eq!(after, cancelled);
    }

    #[test]
    fn test_record_person_answer_property_a_running_run_takes_the_answer(
        answer in prop::sample::select(&ANSWERS[..]),
    ) {
        let test = TestServer::start();

        let (status, after) = block_on(async {
            let started = reach_question(&test).await;
            let owner = &started.account.owner;
            let response =
                answer_step(&test, owner, &started.run, QUESTION_STEP, answer)
                    .await;
            let after = read_run(&test, &started.account, &started.run).await;
            (response.status, after)
        });

        prop_assert_eq!(status, StatusCode::OK);
        prop_assert!(!is_run_finished(after.status), "{:?}", after.status);
        let question = find_step(&after, QUESTION_STEP);
        let is_answered = question.status == StepStatus::Done
            || question.earlier_rounds.len() == 1;
        prop_assert!(is_answered, "{:?}", question);
    }
}
