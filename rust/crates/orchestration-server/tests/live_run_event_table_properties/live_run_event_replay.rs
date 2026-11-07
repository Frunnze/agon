use axum::http::StatusCode;
use chrono::TimeDelta;
use orchestration_core::run::Run;
use orchestration_core::workflow::StepKind;

use crate::branching_fixtures::{
    BranchingRun, branching_workflow, claim_step, read_run,
    start_branching_run,
};
use crate::live_run_event_plans::PostedEvent;
use crate::run_fixtures::post_events;
use crate::test_client::TestServer;

const RUNNER_COUNT: u8 = 1;
const RUNNER_SLOTS: u32 = 4;

#[derive(Debug)]
pub struct ReplayedRun {
    pub initial_run: Run,
    pub acceptances: Vec<bool>,
    pub expected_run: Run,
}

async fn start_held_run(
    test: &TestServer,
    step_names: &[String],
) -> BranchingRun {
    let planned_steps: Vec<(&str, StepKind)> = step_names
        .iter()
        .map(|name| (name.as_str(), StepKind::Agent))
        .collect();
    let workflow = branching_workflow(&planned_steps, &[]);
    let started =
        start_branching_run(test, workflow, RUNNER_COUNT, RUNNER_SLOTS).await;
    for _step_name in step_names {
        let claimed = claim_step(test, &started.runners[0]).await;
        claimed.expect("the only runner claims every independent step");
    }
    started
}

pub async fn replay_posted_events(
    step_names: &[String],
    events: &[PostedEvent],
) -> ReplayedRun {
    let test = TestServer::start();
    let started = start_held_run(&test, step_names).await;
    let initial_run = read_run(&test, &started.account, &started.run).await;
    let holder = &started.runners[0];

    let mut acceptances = Vec::new();
    for posted in events {
        let pause = posted.posted_at - test.now();
        assert!(pause >= TimeDelta::zero(), "events are posted in order");
        test.clock.advance(pause);
        let single_event = vec![posted.event.clone()];
        let (status, _run) =
            post_events(&test, holder, &initial_run, single_event).await;
        acceptances.push(status == StatusCode::OK);
    }

    let expected_run = read_run(&test, &started.account, &started.run).await;
    ReplayedRun {
        initial_run,
        acceptances,
        expected_run,
    }
}
