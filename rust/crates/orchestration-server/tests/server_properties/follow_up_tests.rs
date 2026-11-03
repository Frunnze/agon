use axum::http::StatusCode;
use orchestration_api::work::FollowUp;
use orchestration_core::run::{RunStatus, StepStatus};
use orchestration_core::task::{Task, TaskStatus};
use proptest::prelude::*;

use crate::follow_up_fixtures::{
    RunEnding, active_step_status_strategy, change_step_status, chat_texts,
    claim_assignment, count_waiting_steps, end_run, numbered_text,
    relay_person_message, run_ending_strategy, send_person_message,
    start_claimed_workspace_run,
};
use crate::run_fixtures::start_claimed_run;
use crate::test_client::{TestServer, block_on};

const FOLLOW_UP_CASES: u32 = 12;

fn expected_texts(message_count: usize) -> Vec<String> {
    (0..message_count).map(numbered_text).collect()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FOLLOW_UP_CASES))]

    #[test]
    fn test_send_chat_message_property_a_finished_run_queues_one_follow_up(
        ending in run_ending_strategy(),
        earlier_count in 0_usize..3,
        later_count in 1_usize..4,
    ) {
        let test = TestServer::start();
        let (woken_runs, other_claim, holder_claim, second_claim, tasks) =
            block_on(async {
                let claimed = start_claimed_run(&test).await;
                let owner = &claimed.account.owner;
                change_step_status(&test, &claimed, StepStatus::Running)
                    .await;
                for position in 0..earlier_count {
                    send_person_message(&test, owner, &claimed.run, position)
                        .await;
                }
                end_run(&test, &claimed, ending).await;
                let mut woken_runs = Vec::new();
                for position in earlier_count..earlier_count + later_count {
                    let run = &claimed.run;
                    woken_runs.push(
                        send_person_message(&test, owner, run, position).await,
                    );
                }
                let tasks: Vec<Task> = test.get(owner, "/tasks").await.json();
                let other_claim =
                    claim_assignment(&test, &claimed.other).await;
                let holder_claim =
                    claim_assignment(&test, &claimed.holder).await;
                let second_claim =
                    claim_assignment(&test, &claimed.holder).await;
                (woken_runs, other_claim, holder_claim, second_claim, tasks)
            });

        let message_count = earlier_count + later_count;
        let last_run = woken_runs.last().expect("a message was sent");
        prop_assert_eq!(chat_texts(last_run), expected_texts(message_count));
        for woken_run in &woken_runs {
            prop_assert_eq!(woken_run.status, RunStatus::Queued);
            prop_assert_eq!(count_waiting_steps(woken_run), 1);
            prop_assert!(woken_run.failure.is_none());
            prop_assert!(woken_run.finished_at.is_none());
        }
        prop_assert_eq!(tasks[0].status, TaskStatus::Running);
        prop_assert!(other_claim.is_none());
        let holder_claim = holder_claim.expect("the holder gets it");
        let expected_follow_up = FollowUp {
            answered_user_messages: earlier_count,
        };
        prop_assert_eq!(holder_claim.follow_up, Some(expected_follow_up));
        prop_assert_eq!(&holder_claim.step_name, &last_run.steps[0].name);
        prop_assert_eq!(
            chat_texts(&holder_claim.run),
            expected_texts(message_count)
        );
        prop_assert!(second_claim.is_none());
    }

    #[test]
    fn test_send_chat_message_property_a_running_run_queues_no_follow_up(
        active_status in active_step_status_strategy(),
        message_count in 1_usize..4,
    ) {
        let test = TestServer::start();
        let (sent_runs, holder_id, other_claim, holder_claim) =
            block_on(async {
                let claimed = start_claimed_run(&test).await;
                let owner = &claimed.account.owner;
                change_step_status(&test, &claimed, active_status).await;
                let mut sent_runs = Vec::new();
                for position in 0..message_count {
                    let run = &claimed.run;
                    sent_runs.push(
                        send_person_message(&test, owner, run, position).await,
                    );
                }
                let other_claim =
                    claim_assignment(&test, &claimed.other).await;
                let holder_claim =
                    claim_assignment(&test, &claimed.holder).await;
                let holder_id = claimed.holder.device_id();
                (sent_runs, holder_id, other_claim, holder_claim)
            });

        let last_run = sent_runs.last().expect("a message was sent");
        prop_assert_eq!(chat_texts(last_run), expected_texts(message_count));
        for sent_run in &sent_runs {
            prop_assert_eq!(sent_run.steps[0].status, active_status);
            let step_runner = sent_run.steps[0].runner.as_ref();
            prop_assert_eq!(step_runner, Some(&holder_id));
            prop_assert_eq!(count_waiting_steps(sent_run), 0);
        }
        prop_assert!(other_claim.is_none());
        prop_assert!(holder_claim.is_none());
    }

    #[test]
    fn test_post_run_events_property_a_relayed_message_wakes_a_finished_run(
        ending in run_ending_strategy(),
        relayed_count in 1_usize..4,
    ) {
        let test = TestServer::start();
        let (relayed, holder_claim) = block_on(async {
            let claimed = start_claimed_run(&test).await;
            change_step_status(&test, &claimed, StepStatus::Running).await;
            end_run(&test, &claimed, ending).await;
            let mut relayed = Vec::new();
            for position in 0..relayed_count {
                relayed.push(
                    relay_person_message(&test, &claimed, position).await,
                );
            }
            let holder_claim =
                claim_assignment(&test, &claimed.holder).await;
            (relayed, holder_claim)
        });

        for (status, _run) in &relayed {
            prop_assert_eq!(*status, StatusCode::OK);
        }
        let last_run = relayed
            .last()
            .and_then(|(_status, run)| run.clone())
            .expect("the relayed message is stored");
        prop_assert_eq!(chat_texts(&last_run), expected_texts(relayed_count));
        prop_assert_eq!(last_run.status, RunStatus::Queued);
        prop_assert_eq!(count_waiting_steps(&last_run), 1);
        let holder_claim = holder_claim.expect("the holder gets it");
        let expected_follow_up = FollowUp { answered_user_messages: 0 };
        prop_assert_eq!(holder_claim.follow_up, Some(expected_follow_up));
    }
}

#[test]
fn a_follow_up_of_a_task_without_a_project_returns_to_its_runner() {
    let test = TestServer::start();
    let (woken_run, other_claim, holder_claim) = block_on(async {
        let claimed = start_claimed_workspace_run(&test).await;
        let owner = &claimed.account.owner;
        change_step_status(&test, &claimed, StepStatus::Running).await;
        change_step_status(&test, &claimed, StepStatus::Done).await;
        let woken_run =
            send_person_message(&test, owner, &claimed.run, 0).await;
        let other_claim = claim_assignment(&test, &claimed.other).await;
        let holder_claim = claim_assignment(&test, &claimed.holder).await;
        (woken_run, other_claim, holder_claim)
    });

    assert_eq!(woken_run.status, RunStatus::Queued);
    assert!(other_claim.is_none(), "{other_claim:?}");
    let holder_claim = holder_claim.expect("the session's runner gets it");
    let expected_follow_up = FollowUp {
        answered_user_messages: 0,
    };
    assert_eq!(holder_claim.follow_up, Some(expected_follow_up));
}

#[test]
fn a_retried_run_is_claimed_without_a_follow_up() {
    let test = TestServer::start();
    let retried_claim = block_on(async {
        let claimed = start_claimed_run(&test).await;
        change_step_status(&test, &claimed, StepStatus::Running).await;
        end_run(&test, &claimed, RunEnding::Failed).await;
        let retry_path = format!("/runs/{}/retry", claimed.run.id.0);
        let owner = &claimed.account.owner;
        let retried = test.post_empty(owner, &retry_path).await;
        assert_eq!(retried.status, StatusCode::OK);
        let other_claim = claim_assignment(&test, &claimed.other).await;
        let holder_claim = claim_assignment(&test, &claimed.holder).await;
        other_claim.or(holder_claim)
    });

    let retried_claim = retried_claim.expect("a runner gets the retry");
    assert_eq!(retried_claim.follow_up, None);
}
