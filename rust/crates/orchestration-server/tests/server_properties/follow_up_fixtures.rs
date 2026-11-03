use axum::http::StatusCode;
use orchestration_api::work::{
    RunAssignment, RunEvent, SendChatMessageRequest, TaskStart,
};
use orchestration_core::device::DeviceRole;
use orchestration_core::run::{
    ChatAuthor, ChatMessage, Run, RunFailure, StepStatus,
};
use orchestration_security::identity::DeviceIdentity;
use proptest::prelude::*;

use crate::claim_fixtures::claim;
use crate::fixtures::{
    SEALED_DETAILS, create_account, heartbeat_with, identity_from_seed,
    pair_device, save_task, send_heartbeat, workspace_task,
};
use crate::run_fixtures::{ClaimedRun, claim_by, post_events, run_path};
use crate::test_client::TestServer;

const WORKSPACE_RUNNER_SEEDS: [u8; 2] = [140, 141];
const RUNNER_SLOTS: u32 = 2;

#[derive(Clone, Copy, Debug)]
pub enum RunEnding {
    Done,
    Failed,
    Cancelled,
}

pub fn run_ending_strategy() -> impl Strategy<Value = RunEnding> {
    prop_oneof![
        Just(RunEnding::Done),
        Just(RunEnding::Failed),
        Just(RunEnding::Cancelled),
    ]
}

pub fn active_step_status_strategy() -> impl Strategy<Value = StepStatus> {
    prop_oneof![
        Just(StepStatus::Running),
        Just(StepStatus::WaitingForApproval),
    ]
}

pub fn numbered_text(position: usize) -> String {
    format!("{SEALED_DETAILS}{position}")
}

pub fn person_message(test: &TestServer, position: usize) -> ChatMessage {
    ChatMessage {
        at: test.now(),
        author: ChatAuthor::You,
        text: numbered_text(position),
        is_error: false,
        waiting_to_send: false,
    }
}

pub async fn send_person_message(
    test: &TestServer,
    sender: &DeviceIdentity,
    run: &Run,
    position: usize,
) -> Run {
    let messages_path = format!("{}/messages", run_path(run));
    let request = SendChatMessageRequest {
        message: person_message(test, position),
    };
    let response = test.post(sender, &messages_path, &request).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}

pub async fn relay_person_message(
    test: &TestServer,
    claimed: &ClaimedRun,
    position: usize,
) -> (StatusCode, Option<Run>) {
    let message = person_message(test, position);
    let events = vec![RunEvent::ChatAppended { message }];
    post_events(test, &claimed.holder, &claimed.run, events).await
}

pub async fn change_step_status(
    test: &TestServer,
    claimed: &ClaimedRun,
    status: StepStatus,
) {
    let event = RunEvent::StepStatusChanged {
        step_name: claimed.run.steps[0].name.clone(),
        status,
    };
    let events = vec![event];
    let (response_status, _run) =
        post_events(test, &claimed.holder, &claimed.run, events).await;
    assert_eq!(response_status, StatusCode::OK);
}

pub async fn end_run(
    test: &TestServer,
    claimed: &ClaimedRun,
    ending: RunEnding,
) {
    match ending {
        RunEnding::Done => {
            change_step_status(test, claimed, StepStatus::Done).await;
        }
        RunEnding::Failed => {
            let failure = RunFailure {
                step_name: claimed.run.steps[0].name.clone(),
                runner: Some(claimed.holder.device_id()),
                reason: SEALED_DETAILS.to_owned(),
                retry_runs_on_same_runner: false,
            };
            let events = vec![RunEvent::Failed { failure }];
            let (status, _run) =
                post_events(test, &claimed.holder, &claimed.run, events).await;
            assert_eq!(status, StatusCode::OK);
        }
        RunEnding::Cancelled => {
            let cancel_path = format!("{}/cancel", run_path(&claimed.run));
            let owner = &claimed.account.owner;
            let response = test.post_empty(owner, &cancel_path).await;
            assert_eq!(response.status, StatusCode::OK);
        }
    }
}

pub async fn claim_assignment(
    test: &TestServer,
    runner: &DeviceIdentity,
) -> Option<RunAssignment> {
    claim(test, runner).await.assignment
}

pub fn chat_texts(run: &Run) -> Vec<String> {
    let mut texts = Vec::new();
    for message in &run.chat {
        texts.push(message.text.clone());
    }
    texts
}

pub fn count_waiting_steps(run: &Run) -> usize {
    let mut waiting_count = 0;
    for step in &run.steps {
        let is_unclaimed_wait =
            step.status == StepStatus::Waiting && step.runner.is_none();
        if is_unclaimed_wait {
            waiting_count += 1;
        }
    }
    waiting_count
}

pub async fn start_claimed_workspace_run(test: &TestServer) -> ClaimedRun {
    let account = create_account(test).await;
    let mut runners = Vec::new();
    for seed in WORKSPACE_RUNNER_SEEDS {
        let identity = identity_from_seed(seed);
        let name = format!("runner-{seed}");
        pair_device(test, &account, &identity, &name, DeviceRole::Runner)
            .await;
        let heartbeat = heartbeat_with(&[], RUNNER_SLOTS, 0);
        send_heartbeat(test, &identity, &heartbeat).await;
        runners.push(identity);
    }
    let task = workspace_task(account.workspace_id);
    save_task(test, &account, task, TaskStart::Now).await;

    let [first, second] = <[DeviceIdentity; 2]>::try_from(runners)
        .expect("two runners are paired");
    if let Some(run) = claim_by(test, &first).await {
        return ClaimedRun {
            account,
            holder: first,
            other: second,
            run,
        };
    }
    let run = claim_by(test, &second)
        .await
        .expect("one of the runners gets the run");
    ClaimedRun {
        account,
        holder: second,
        other: first,
        run,
    }
}
