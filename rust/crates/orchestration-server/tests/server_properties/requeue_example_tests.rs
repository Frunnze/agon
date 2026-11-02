use axum::http::StatusCode;
use chrono::TimeDelta;
use orchestration_core::device::RunnerTarget;
use orchestration_core::run::{Run, RunStatus, StepStatus};
use orchestration_server::{ABANDONED_STEP_TIMEOUT, requeue_abandoned_steps};

use crate::claim_fixtures::{claim, pair_runners, queue_runs};
use crate::fixtures::{create_account, create_project, heartbeat_with};
use crate::requeue_fixtures::revoke_runner;
use crate::run_fixtures::{claim_by, start_claimed_run};
use crate::test_client::{TestServer, block_on};

const REQUEUE_NOTE: &str = "back to the queue";

fn stored_run(test: &TestServer, run: &Run) -> Run {
    let state = test.server.snapshot_state().expect("the state is readable");
    state.runs[&run.id].run.clone()
}

fn latest_audit_event(test: &TestServer) -> String {
    let state = test.server.snapshot_state().expect("the state is readable");
    let latest_entry = state.audit_log.last().expect("the audit log notes it");
    latest_entry.event.clone()
}

fn pass_the_timeout(test: &TestServer) {
    test.clock
        .advance(ABANDONED_STEP_TIMEOUT + TimeDelta::seconds(1));
}

#[test]
fn offline_runners_lose_their_steps_with_a_note_in_the_log() {
    let test = TestServer::start();
    let (released_count, requeued_run, audit_event, claimed_again) =
        block_on(async {
            let claimed = start_claimed_run(&test).await;
            pass_the_timeout(&test);
            let heartbeat = heartbeat_with(&[], 2, 0);
            let path = "/runners/heartbeat";
            test.post(&claimed.other, path, &heartbeat).await;
            let released_count = requeue_abandoned_steps(&test.server)
                .expect("the requeue is saved");
            let requeued_run = stored_run(&test, &claimed.run);
            let audit_event = latest_audit_event(&test);
            let claimed_again = claim_by(&test, &claimed.other).await;
            (released_count, requeued_run, audit_event, claimed_again)
        });

    assert_eq!(released_count, 1);
    assert_eq!(requeued_run.status, RunStatus::Queued);
    assert_eq!(requeued_run.steps[0].status, StepStatus::Waiting);
    assert_eq!(requeued_run.steps[0].runner, None);
    assert!(requeued_run.log.is_empty(), "{:?}", requeued_run.log);
    assert!(audit_event.contains(REQUEUE_NOTE), "{audit_event}");
    assert_eq!(claimed_again.map(|run| run.id), Some(requeued_run.id));
}

#[test]
fn revoked_runners_lose_their_steps_at_the_next_pass() {
    let test = TestServer::start();
    let (released_count, requeued_run) = block_on(async {
        let claimed = start_claimed_run(&test).await;
        let status =
            revoke_runner(&test, &claimed.account, &claimed.holder).await;
        assert_eq!(status, StatusCode::OK);
        let released_count = requeue_abandoned_steps(&test.server)
            .expect("the requeue is saved");
        (released_count, stored_run(&test, &claimed.run))
    });

    assert_eq!(released_count, 1);
    assert_eq!(requeued_run.steps[0].runner, None);
}

#[test]
fn pinned_steps_wait_for_their_runner() {
    let test = TestServer::start();
    let (released_count, assignment_run, waiting_run) = block_on(async {
        let account = create_account(&test).await;
        let project = create_project(&test, &account).await;
        let runners = pair_runners(&test, &account, 1, 2).await;
        let target = RunnerTarget::SpecificRunner {
            device_id: runners[0].device_id(),
        };
        queue_runs(&test, &account, project.id, &target, 1).await;
        let assignment = claim(&test, &runners[0])
            .await
            .assignment
            .expect("the pinned runner gets its run");
        pass_the_timeout(&test);
        let released_count = requeue_abandoned_steps(&test.server)
            .expect("the requeue pass works");
        let waiting_run = stored_run(&test, &assignment.run);
        (released_count, assignment.run, waiting_run)
    });

    assert_eq!(released_count, 0);
    assert_eq!(waiting_run.steps, assignment_run.steps);
}
