use std::sync::Arc;

use orchestration_api::work::{HeartbeatRequest, RunAssignment};
use orchestration_core::device::{RunnerLink, SandboxKind};
use orchestration_node::runner_bridge::NodeRunnerServer;
use orchestration_runner::runner_server::RunnerServer;
use serde_json::{Value, json};
use tokio::runtime::Runtime;

use super::command_builders::{PreparedWorkspace, create_task_command};
use super::test_device::describe;

const RUNTIME_WORKER_THREADS: usize = 2;
const SAMPLE_SLOT_COUNT: u32 = 2;

#[derive(Debug)]
pub struct ClaimedRun {
    pub prepared: PreparedWorkspace,
    pub runner: Arc<NodeRunnerServer>,
    pub runtime: Runtime,
    pub assignment: RunAssignment,
}

pub fn test_runtime() -> Result<Runtime, String> {
    tokio::runtime::Builder::new_multi_thread()
        .worker_threads(RUNTIME_WORKER_THREADS)
        .enable_all()
        .build()
        .map_err(describe)
}

pub fn sample_heartbeat() -> HeartbeatRequest {
    HeartbeatRequest {
        labels: vec!["mac".to_owned()],
        slots_total: SAMPLE_SLOT_COUNT,
        slots_busy: 0,
        link: RunnerLink::Direct,
        sandbox: SandboxKind::LocalProcess,
        allowed_hosts: Vec::new(),
        cached_repositories: Vec::new(),
    }
}

pub fn started_task_command(
    prepared: &PreparedWorkspace,
    details: &str,
) -> Value {
    let mut command = create_task_command(
        &prepared.workspace_id,
        &prepared.project_id,
        details,
    );
    command["start"] = json!("now");
    command
}

pub fn open_runner(
    prepared: &PreparedWorkspace,
) -> Result<Arc<NodeRunnerServer>, String> {
    Ok(Arc::new(prepared.device.open_runner_server()?))
}

pub fn claim_next_assignment(
    runner: &NodeRunnerServer,
    runtime: &Runtime,
) -> Result<RunAssignment, String> {
    let heartbeat = sample_heartbeat();
    runtime
        .block_on(runner.send_heartbeat(&heartbeat))
        .map_err(describe)?;
    let response = runtime
        .block_on(runner.claim_next_run())
        .map_err(describe)?;
    response
        .assignment
        .ok_or_else(|| "no run was given to the runner".to_owned())
}

pub fn claim_started_task(
    prepared: PreparedWorkspace,
    task_command: &Value,
) -> Result<ClaimedRun, String> {
    prepared.device.run(task_command)?;
    let runtime = test_runtime()?;
    let runner = open_runner(&prepared)?;
    let assignment = claim_next_assignment(&runner, &runtime)?;
    Ok(ClaimedRun {
        prepared,
        runner,
        runtime,
        assignment,
    })
}
