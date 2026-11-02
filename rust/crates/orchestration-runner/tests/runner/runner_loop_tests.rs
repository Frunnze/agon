use std::sync::Arc;
use std::sync::Mutex;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Duration;

use orchestration_api::work::RunAssignment;
use orchestration_core::identifiers::RunId;
use orchestration_hub::cached_clones::cached_clone_folder;
use orchestration_runner::run_executor::{RunExecutor, RunOutcome};
use orchestration_runner::runner_configuration::{
    ConfigurationProblem, RunnerConfiguration,
};
use orchestration_runner::runner_loop::{RunnerError, run_runner_loop};
use proptest::prelude::*;
use tokio::runtime::Builder;
use tokio::time::sleep;

use crate::assignments::claude_assignment;
use crate::fake_agent::{
    RUNNER_LABEL, local_configuration, prepare_agent_folders,
};
use crate::fake_server::FakeServer;
use crate::support::{TestResult, hold, to_case_error};

const RUN_DURATION: Duration = Duration::from_millis(30);
const SHUTDOWN_POLL: Duration = Duration::from_millis(1);
const FIRST_RUN_NUMBER: u128 = 0x7000;

#[derive(Debug, Default)]
struct CountingExecutor {
    currently_active: AtomicUsize,
    peak_active: AtomicUsize,
    executed_run_ids: Mutex<Vec<RunId>>,
}

impl RunExecutor for CountingExecutor {
    async fn execute(&self, assignment: RunAssignment) -> RunOutcome {
        let now_active =
            self.currently_active.fetch_add(1, Ordering::SeqCst) + 1;
        self.peak_active.fetch_max(now_active, Ordering::SeqCst);
        sleep(RUN_DURATION).await;
        self.currently_active.fetch_sub(1, Ordering::SeqCst);
        hold(&self.executed_run_ids).push(assignment.run.id);
        RunOutcome::Finished
    }
}

impl CountingExecutor {
    fn executed_count(&self) -> usize {
        hold(&self.executed_run_ids).len()
    }
}

#[derive(Clone, Copy, Debug)]
enum StopCondition {
    ExecutedRunCount(usize),
    FirstRunStarted,
    FirstHeartbeatSent,
}

fn is_condition_met(
    condition: StopCondition,
    executor: &CountingExecutor,
    server: &FakeServer,
) -> bool {
    match condition {
        StopCondition::ExecutedRunCount(count) => {
            executor.executed_count() >= count
        }
        StopCondition::FirstRunStarted => {
            executor.currently_active.load(Ordering::SeqCst) > 0
        }
        StopCondition::FirstHeartbeatSent => !server.heartbeats().is_empty(),
    }
}

struct LoopResult {
    executed_run_ids: Vec<RunId>,
    peak_active: usize,
    server: Arc<FakeServer>,
}

fn queued_assignments(count: usize) -> TestResult<Vec<RunAssignment>> {
    let mut assignments = Vec::new();
    for offset in 0..count {
        let number = FIRST_RUN_NUMBER + u128::try_from(offset)?;
        assignments.push(claude_assignment(number, "Queued work")?);
    }
    Ok(assignments)
}

fn run_loop_until(
    configuration: &RunnerConfiguration,
    assignments: Vec<RunAssignment>,
    condition: StopCondition,
) -> TestResult<LoopResult> {
    let runtime = Builder::new_current_thread()
        .enable_time()
        .start_paused(true)
        .build()?;
    let server = Arc::new(FakeServer::with_queue(assignments));
    let executor = Arc::new(CountingExecutor::default());
    let watched_executor = Arc::clone(&executor);
    let watched_server = Arc::clone(&server);
    let shutdown = async move {
        while !is_condition_met(condition, &watched_executor, &watched_server)
        {
            sleep(SHUTDOWN_POLL).await;
        }
    };

    runtime.block_on(run_runner_loop(
        Arc::clone(&server),
        Arc::clone(&executor),
        configuration,
        shutdown,
    ))?;
    Ok(LoopResult {
        executed_run_ids: hold(&executor.executed_run_ids).clone(),
        peak_active: executor.peak_active.load(Ordering::SeqCst),
        server,
    })
}

#[test]
fn finishes_the_runs_in_progress_before_shutting_down() -> TestResult<()> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 2)?;
    let assignments = queued_assignments(5)?;

    let condition = StopCondition::FirstRunStarted;

    let result = run_loop_until(&configuration, assignments, condition)?;

    assert_eq!(result.executed_run_ids.len(), 2);
    assert_eq!(result.server.queued_count(), 3);
    Ok(())
}

#[test]
fn sends_a_heartbeat_with_its_labels_as_it_starts() -> TestResult<()> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 3)?;

    let condition = StopCondition::FirstHeartbeatSent;

    let result = run_loop_until(&configuration, Vec::new(), condition)?;

    let heartbeats = result.server.heartbeats();
    let first = heartbeats.first().ok_or("no heartbeat was sent")?;
    assert_eq!(first.labels, vec![RUNNER_LABEL.to_string()]);
    assert_eq!(first.slots_total, 3);
    assert_eq!(first.slots_busy, 0);
    Ok(())
}

#[test]
fn names_the_cached_repositories_in_its_heartbeat() -> TestResult<()> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let address = "github.com/acme/app";
    let clone = cached_clone_folder(&folders.cache_root, address);
    std::fs::create_dir_all(clone.join(".git"))?;

    let condition = StopCondition::FirstHeartbeatSent;

    let result = run_loop_until(&configuration, Vec::new(), condition)?;

    let heartbeats = result.server.heartbeats();
    let first = heartbeats.first().ok_or("no heartbeat was sent")?;
    assert_eq!(first.cached_repositories, [address]);
    Ok(())
}

#[test]
fn refuses_to_start_without_slots() -> TestResult<()> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 0)?;

    let condition = StopCondition::FirstHeartbeatSent;

    let started = run_loop_until(&configuration, Vec::new(), condition);

    let problem = started.err().ok_or("the loop started")?;
    let runner_problem = problem.downcast_ref::<RunnerError>();
    assert!(matches!(
        runner_problem,
        Some(RunnerError::Configuration(ConfigurationProblem::NoSlots))
    ));
    Ok(())
}

#[test]
fn runs_as_a_sendable_future() -> TestResult<()> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let server = Arc::new(FakeServer::with_queue(Vec::new()));
    let executor = Arc::new(CountingExecutor::default());

    let runner_loop =
        run_runner_loop(server, executor, &configuration, async {});

    require_sendable(&runner_loop);
    Ok(())
}

fn require_sendable<T: Send>(_value: &T) {}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(48))]

    #[test]
    fn test_run_runner_loop_property_never_exceeds_its_slot_capacity(
        slot_capacity in 1_u32..5,
        queued_count in 0_usize..14,
    ) {
        let folders = prepare_agent_folders().map_err(to_case_error)?;
        let configuration = local_configuration(&folders, slot_capacity)
            .map_err(to_case_error)?;
        let assignments =
            queued_assignments(queued_count).map_err(to_case_error)?;
        let mut queued_ids: Vec<RunId> =
            assignments.iter().map(|assignment| assignment.run.id).collect();

        let condition = StopCondition::ExecutedRunCount(queued_count);

        let result = run_loop_until(&configuration, assignments, condition)
            .map_err(to_case_error)?;

        let capacity = usize::try_from(slot_capacity).map_err(to_case_error)?;
        prop_assert!(result.peak_active <= capacity);
        prop_assert_eq!(result.peak_active, capacity.min(queued_count));
        let mut executed_ids = result.executed_run_ids.clone();
        executed_ids.sort();
        queued_ids.sort();
        prop_assert_eq!(executed_ids, queued_ids);
        for heartbeat in result.server.heartbeats() {
            prop_assert!(heartbeat.slots_busy <= heartbeat.slots_total);
            prop_assert_eq!(heartbeat.slots_total, slot_capacity);
        }
    }
}
