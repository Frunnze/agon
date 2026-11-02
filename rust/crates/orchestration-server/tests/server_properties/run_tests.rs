use axum::http::StatusCode;
use orchestration_api::work::{RunEvent, SendChatMessageRequest};
use orchestration_core::device::RunnerLink;
use orchestration_core::run::{
    ChatAuthor, ChatMessage, Run, RunFailure, RunStatus, StepStatus,
};
use orchestration_core::task::{Task, TaskStatus};

use crate::fixtures::SEALED_DETAILS;
use crate::run_fixtures::{
    claim_by, post_events, run_path, start_claimed_run,
};
use crate::test_client::{TestServer, block_on};

#[test]
fn runner_events_update_session_branch_link_and_chat() {
    let test = TestServer::start();
    let updated_run = block_on(async {
        let claimed = start_claimed_run(&test).await;
        let message = ChatMessage {
            at: test.now(),
            author: ChatAuthor::Agent,
            text: SEALED_DETAILS.to_owned(),
            is_error: false,
            waiting_to_send: false,
        };
        let events = vec![
            RunEvent::WorktreeCreated {
                branch: "task/ship-release-2-4".to_owned(),
            },
            RunEvent::SessionStarted {
                session: "7c1e".to_owned(),
            },
            RunEvent::LinkChanged {
                link: RunnerLink::Direct,
            },
            RunEvent::ChatAppended { message },
            RunEvent::Finished,
        ];
        post_events(&test, &claimed.holder, &claimed.run, events)
            .await
            .1
    });

    let updated_run = updated_run.expect("the events are accepted");
    assert_eq!(
        updated_run.worktree_branch.as_deref(),
        Some("task/ship-release-2-4")
    );
    assert_eq!(updated_run.agent_session.as_deref(), Some("7c1e"));
    assert_eq!(updated_run.link, RunnerLink::Direct);
    assert_eq!(updated_run.chat.len(), 1);
    assert_eq!(updated_run.status, RunStatus::Done);
}

#[test]
fn other_runners_can_neither_see_nor_change_the_run() {
    let test = TestServer::start();
    let (read_status, events_status, listed_runs) = block_on(async {
        let claimed = start_claimed_run(&test).await;
        let read = test.get(&claimed.other, &run_path(&claimed.run)).await;
        let (events_status, _run) = post_events(
            &test,
            &claimed.other,
            &claimed.run,
            vec![RunEvent::Finished],
        )
        .await;
        let listed_runs: Vec<Run> =
            test.get(&claimed.other, "/runs").await.json();
        (read.status, events_status, listed_runs)
    });

    assert_eq!(read_status, StatusCode::FORBIDDEN);
    assert_eq!(events_status, StatusCode::FORBIDDEN);
    assert_eq!(listed_runs.len(), 0);
}

#[test]
fn failed_runs_retry_on_the_pinned_runner() {
    let test = TestServer::start();
    let (retried, other_claim, holder_claim) = block_on(async {
        let claimed = start_claimed_run(&test).await;
        let step_name = claimed.run.steps[0].name.clone();
        let failure = RunFailure {
            step_name,
            runner: Some(claimed.holder.device_id()),
            reason: SEALED_DETAILS.to_owned(),
            retry_runs_on_same_runner: true,
        };
        let (status, failed_run) = post_events(
            &test,
            &claimed.holder,
            &claimed.run,
            vec![RunEvent::Failed { failure }],
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        let failed_run = failed_run.expect("the failure is stored");
        assert_eq!(failed_run.status, RunStatus::Failed);
        let retry_path = format!("{}/retry", run_path(&claimed.run));
        let retried: Run = test
            .post_empty(&claimed.account.owner, &retry_path)
            .await
            .json();
        let other_claim = claim_by(&test, &claimed.other).await;
        let holder_claim = claim_by(&test, &claimed.holder).await;
        (retried, other_claim, holder_claim)
    });

    assert_eq!(retried.status, RunStatus::Queued);
    assert!(retried.failure.is_none());
    assert!(other_claim.is_none());
    assert_eq!(holder_claim.map(|run| run.id), Some(retried.id));
}

#[test]
fn cancelled_runs_stop_and_refuse_step_changes() {
    let test = TestServer::start();
    let (cancelled, repeated_status, events_status, tasks) = block_on(async {
        let claimed = start_claimed_run(&test).await;
        let cancel_path = format!("{}/cancel", run_path(&claimed.run));
        let cancelled: Run = test
            .post_empty(&claimed.account.owner, &cancel_path)
            .await
            .json();
        let repeated =
            test.post_empty(&claimed.account.owner, &cancel_path).await;
        let event = RunEvent::StepStatusChanged {
            step_name: claimed.run.steps[0].name.clone(),
            status: StepStatus::Running,
        };
        let (events_status, _run) =
            post_events(&test, &claimed.holder, &claimed.run, vec![event])
                .await;
        let tasks: Vec<Task> =
            test.get(&claimed.account.owner, "/tasks").await.json();
        (cancelled, repeated.status, events_status, tasks)
    });

    assert_eq!(cancelled.status, RunStatus::Cancelled);
    assert!(cancelled.finished_at.is_some());
    assert_eq!(repeated_status, StatusCode::CONFLICT);
    assert_eq!(events_status, StatusCode::CONFLICT);
    assert_eq!(tasks[0].status, TaskStatus::ToDo);
}

#[test]
fn client_chat_messages_reach_the_runner() {
    let test = TestServer::start();
    let runner_view = block_on(async {
        let claimed = start_claimed_run(&test).await;
        let message = ChatMessage {
            at: test.now(),
            author: ChatAuthor::You,
            text: SEALED_DETAILS.to_owned(),
            is_error: false,
            waiting_to_send: true,
        };
        let messages_path = format!("{}/messages", run_path(&claimed.run));
        let request = SendChatMessageRequest { message };
        let response = test
            .post(&claimed.account.owner, &messages_path, &request)
            .await;
        assert_eq!(response.status, StatusCode::OK);
        let runner_view: Run = test
            .get(&claimed.holder, &run_path(&claimed.run))
            .await
            .json();
        runner_view
    });

    assert_eq!(runner_view.chat.len(), 1);
    assert_eq!(runner_view.chat[0].author, ChatAuthor::You);
}
