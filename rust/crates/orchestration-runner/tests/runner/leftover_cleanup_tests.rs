use std::collections::BTreeSet;
use std::fs;
use std::future::ready;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use orchestration_api::work::{ForgottenWork, RunAssignment};
use orchestration_core::identifiers::TaskId;
use orchestration_runner::run_executor::{RunExecutor, RunOutcome};
use orchestration_runner::runner_loop::run_runner_loop;
use proptest::collection::vec;
use proptest::prelude::*;
use tokio::runtime::Builder;
use tokio::time::sleep;
use uuid::Uuid;

use crate::fake_agent::{
    AgentFolders, local_configuration, prepare_agent_folders,
};
use crate::fake_server::FakeServer;
use crate::support::{TestResult, to_case_error};

const CLEANUP_CASES: u32 = 16;
const SHUTDOWN_POLL: Duration = Duration::from_millis(1);
const FIRST_TASK_NUMBER: u128 = 0x4400;
const STRANGER_FOLDER_NAME: &str = "my-own-notes";

struct ExecutorWithoutWork;

impl RunExecutor for ExecutorWithoutWork {
    fn execute(
        &self,
        _assignment: RunAssignment,
    ) -> impl Future<Output = RunOutcome> + Send {
        ready(RunOutcome::Finished)
    }
}

struct HeldTaskFolder {
    task_id: TaskId,
    folder: PathBuf,
}

fn create_task_folders(
    folders: &AgentFolders,
    count: usize,
) -> TestResult<Vec<HeldTaskFolder>> {
    let mut held_folders = Vec::new();
    for position in 0..count {
        let number = FIRST_TASK_NUMBER + u128::try_from(position)?;
        let task_id = TaskId(Uuid::from_u128(number));
        let name = format!("task-{position}-{}", task_id.0.simple());
        let folder = folders.worktrees_root.join(name);
        fs::create_dir_all(folder.join("app"))?;
        held_folders.push(HeldTaskFolder { task_id, folder });
    }
    Ok(held_folders)
}

fn run_until_first_heartbeat(
    folders: &AgentFolders,
    server: &Arc<FakeServer>,
) -> TestResult<()> {
    let configuration = local_configuration(folders, 1)?;
    let runtime = Builder::new_current_thread()
        .enable_time()
        .start_paused(true)
        .build()?;
    let watched_server = Arc::clone(server);
    let shutdown = async move {
        while watched_server.heartbeats().is_empty() {
            sleep(SHUTDOWN_POLL).await;
        }
    };

    runtime.block_on(run_runner_loop(
        Arc::clone(server),
        Arc::new(ExecutorWithoutWork),
        &configuration,
        shutdown,
    ))?;
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CLEANUP_CASES))]

    #[test]
    fn test_run_runner_loop_property_an_idle_runner_removes_forgotten_work(
        forgotten_flags in vec(any::<bool>(), 0..5),
    ) {
        let folders = prepare_agent_folders().map_err(to_case_error)?;
        let held_folders =
            create_task_folders(&folders, forgotten_flags.len())
                .map_err(to_case_error)?;
        let stranger = folders.worktrees_root.join(STRANGER_FOLDER_NAME);
        fs::create_dir_all(&stranger).map_err(to_case_error)?;
        let mut forgotten_tasks = Vec::new();
        for (held, is_forgotten) in held_folders.iter().zip(&forgotten_flags) {
            if *is_forgotten {
                forgotten_tasks.push(held.task_id);
            }
        }
        let forgotten_work = ForgottenWork {
            forgotten_tasks: forgotten_tasks.clone(),
            unused_repositories: Vec::new(),
        };
        let server = Arc::new(
            FakeServer::with_queue(Vec::new()).forgetting(forgotten_work),
        );

        run_until_first_heartbeat(&folders, &server).map_err(to_case_error)?;

        let heartbeats = server.heartbeats();
        let announced: BTreeSet<TaskId> =
            heartbeats[0].held_tasks.iter().copied().collect();
        let on_disk: BTreeSet<TaskId> =
            held_folders.iter().map(|held| held.task_id).collect();
        prop_assert_eq!(announced, on_disk);
        for held in &held_folders {
            let is_forgotten = forgotten_tasks.contains(&held.task_id);
            prop_assert_eq!(held.folder.exists(), !is_forgotten);
        }
        prop_assert!(stranger.exists());
    }
}
