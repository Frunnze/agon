use std::collections::BTreeMap;

use axum::http::StatusCode;
use chrono::{DateTime, TimeDelta, Utc};
use orchestration_core::identifiers::{DeviceId, RunId};
use orchestration_core::run::{RunStatus, StepStatus};
use orchestration_server::{
    ABANDONED_STEP_TIMEOUT, StoredState, requeue_abandoned_steps,
};
use proptest::prelude::*;

use crate::fixtures::heartbeat_with;
use crate::requeue_fixtures::{
    RUNNER_COUNT, RequeueSetup, SLOTS_PER_RUNNER, claim_as, is_pinned_to,
    prepare_requeue, revoke_runner,
};
use crate::test_client::{TestServer, block_on};

const MAXIMUM_ADVANCE_SECONDS: i64 = 240;

#[derive(Clone, Copy, Debug)]
enum Action {
    Heartbeat(usize),
    Claim(usize),
    Advance(i64),
    Revoke(usize),
    SchedulerPass,
}

#[derive(Debug, Default)]
struct RunnerModel {
    last_seen: BTreeMap<DeviceId, DateTime<Utc>>,
    revoked: Vec<DeviceId>,
}

impl RunnerModel {
    fn is_abandoned_by(
        &self,
        runner_id: &DeviceId,
        now: DateTime<Utc>,
    ) -> bool {
        let is_revoked = self.revoked.contains(runner_id);
        let is_silent = self
            .last_seen
            .get(runner_id)
            .is_none_or(|seen_at| now - *seen_at > ABANDONED_STEP_TIMEOUT);
        is_revoked || is_silent
    }
}

fn action_strategy() -> impl Strategy<Value = Action> {
    let runner = 0..usize::from(RUNNER_COUNT);
    prop_oneof![
        runner.clone().prop_map(Action::Heartbeat),
        runner.clone().prop_map(Action::Claim),
        (0..MAXIMUM_ADVANCE_SECONDS).prop_map(Action::Advance),
        runner.prop_map(Action::Revoke),
        Just(Action::SchedulerPass),
    ]
}

fn held_steps(state: &StoredState) -> Vec<(RunId, DeviceId)> {
    let mut held = Vec::new();
    for record in state.runs.values() {
        let run = &record.run;
        let is_active = matches!(
            run.status,
            RunStatus::Queued
                | RunStatus::Running
                | RunStatus::WaitingForApproval
        );
        for step in &run.steps {
            let is_unfinished = matches!(
                step.status,
                StepStatus::Waiting
                    | StepStatus::Running
                    | StepStatus::WaitingForApproval
            );
            if let Some(holder) = &step.runner
                && is_active
                && is_unfinished
            {
                held.push((run.id, holder.clone()));
            }
        }
    }
    held
}

fn snapshot(test: &TestServer) -> StoredState {
    test.server.snapshot_state().expect("the state is readable")
}

fn perform_action(
    test: &TestServer,
    setup: &RequeueSetup,
    model: &mut RunnerModel,
    action: Action,
) {
    match action {
        Action::Heartbeat(position) => {
            let runner = &setup.runners[position];
            let heartbeat = heartbeat_with(&[], SLOTS_PER_RUNNER, 0);
            let path = "/runners/heartbeat";
            let response = block_on(test.post(runner, path, &heartbeat));
            if response.status == StatusCode::OK {
                model.last_seen.insert(runner.device_id(), test.now());
            }
        }
        Action::Claim(position) => {
            let runner = &setup.runners[position];
            let (status, _claim) = block_on(claim_as(test, runner));
            if status == StatusCode::OK {
                model.last_seen.insert(runner.device_id(), test.now());
            }
        }
        Action::Advance(seconds) => {
            test.clock.advance(TimeDelta::seconds(seconds));
        }
        Action::Revoke(position) => {
            let runner = &setup.runners[position];
            let status = block_on(revoke_runner(test, &setup.account, runner));
            if status == StatusCode::OK {
                model.revoked.push(runner.device_id());
            }
        }
        Action::SchedulerPass => {
            requeue_abandoned_steps(&test.server)
                .expect("the scheduler pass saves its changes");
        }
    }
}

fn find_abandoned_holders(
    state: &StoredState,
    model: &RunnerModel,
    now: DateTime<Utc>,
) -> Vec<(RunId, DeviceId)> {
    let mut abandoned = Vec::new();
    for (run_id, holder) in held_steps(state) {
        let task_id = state.runs[&run_id].run.task_id;
        let is_pinned = is_pinned_to(state, task_id, &holder);
        if !is_pinned && model.is_abandoned_by(&holder, now) {
            abandoned.push((run_id, holder));
        }
    }
    abandoned
}

fn record_pinned_holders(
    state: &StoredState,
    pinned_runner: &DeviceId,
    pinned_holders: &mut BTreeMap<RunId, DeviceId>,
) {
    for (run_id, holder) in held_steps(state) {
        let task_id = state.runs[&run_id].run.task_id;
        if is_pinned_to(state, task_id, pinned_runner) {
            pinned_holders.insert(run_id, holder);
        }
    }
}

fn count_moved_pinned_steps(
    state: &StoredState,
    pinned_runner: &DeviceId,
    pinned_holders: &BTreeMap<RunId, DeviceId>,
) -> usize {
    let mut moved_count = 0;
    for (run_id, holder) in pinned_holders {
        let current_holder = state.runs[run_id].run.steps[0].runner.as_ref();
        let has_moved =
            current_holder != Some(holder) || holder != pinned_runner;
        moved_count += usize::from(has_moved);
    }
    moved_count
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(24))]

    #[test]
    fn test_requeue_abandoned_steps_property_no_step_stays_abandoned(
        actions in proptest::collection::vec(action_strategy(), 1..24),
    ) {
        let test = TestServer::start();
        let setup = block_on(prepare_requeue(&test));
        let mut model = RunnerModel::default();
        for runner in &setup.runners {
            model.last_seen.insert(runner.device_id(), test.now());
        }
        let mut pinned_holders = BTreeMap::new();

        for action in actions {
            perform_action(&test, &setup, &mut model, action);
            let state = snapshot(&test);
            if matches!(action, Action::SchedulerPass) {
                let abandoned =
                    find_abandoned_holders(&state, &model, test.now());
                prop_assert_eq!(abandoned, Vec::new());
            }
            let pinned_runner = &setup.pinned_runner;
            record_pinned_holders(&state, pinned_runner, &mut pinned_holders);
            let moved_count = count_moved_pinned_steps(
                &state,
                pinned_runner,
                &pinned_holders,
            );
            prop_assert_eq!(moved_count, 0);
        }
    }
}
