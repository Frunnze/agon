use std::sync::Arc;
use std::time::Duration;

use orchestration_api::work::{RunAssignment, RunEvent};
use orchestration_core::identifiers::RunId;
use orchestration_core::run::StepStatus;
use orchestration_runner::runner::run_runner;
use proptest::prelude::*;
use tokio::runtime::Runtime;
use tokio::time::sleep;

use crate::assignments::claude_assignment;
use crate::event_queries::{has_status, step_statuses};
use crate::fake_agent::{local_configuration, prepare_agent_folders};
use crate::fake_server::FakeServer;
use crate::support::{TestResult, to_case_error};

const FIRST_RUN_NUMBER: u128 = 0xe000;
const FINISH_POLL: Duration = Duration::from_millis(10);

fn queue_work(count: usize) -> TestResult<Vec<RunAssignment>> {
    let mut assignments = Vec::new();
    for offset in 0..count {
        let number = FIRST_RUN_NUMBER + u128::try_from(offset)?;
        let title = format!("work-{offset}");
        assignments.push(claude_assignment(number, &title)?);
    }
    Ok(assignments)
}

fn has_every_run_finished(server: &FakeServer, run_ids: &[RunId]) -> bool {
    run_ids
        .iter()
        .all(|run_id| has_status(&server.events_of(*run_id), StepStatus::Done))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(4))]

    #[test]
    fn test_run_runner_property_finishes_every_queued_run_once(
        slot_capacity in 1_u32..4,
        queued_count in 0_usize..4,
    ) {
        let folders = prepare_agent_folders().map_err(to_case_error)?;
        let configuration = local_configuration(&folders, slot_capacity)
            .map_err(to_case_error)?;
        let assignments = queue_work(queued_count).map_err(to_case_error)?;
        let run_ids: Vec<RunId> =
            assignments.iter().map(|assignment| assignment.run.id).collect();
        let server = Arc::new(FakeServer::with_queue(assignments));
        let watched_server = Arc::clone(&server);
        let watched_runs = run_ids.clone();
        let shutdown = async move {
            while !has_every_run_finished(&watched_server, &watched_runs) {
                sleep(FINISH_POLL).await;
            }
        };
        let runtime = Runtime::new().map_err(to_case_error)?;

        let runner_server = Arc::clone(&server);
        let running = run_runner(runner_server, &configuration, shutdown);
        runtime.block_on(running).map_err(to_case_error)?;

        for run_id in &run_ids {
            let events = server.events_of(*run_id);
            let statuses: Vec<StepStatus> = step_statuses(&events)
                .into_iter()
                .map(|(_name, status)| status)
                .collect();
            prop_assert!(!events.contains(&RunEvent::Finished));
            prop_assert_eq!(
                statuses,
                vec![StepStatus::Running, StepStatus::Done]
            );
        }
        for heartbeat in server.heartbeats() {
            prop_assert!(heartbeat.slots_busy <= slot_capacity);
        }
    }
}
