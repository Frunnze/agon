use std::sync::Arc;
use std::time::Duration;

use orchestration_p2p::peer_endpoint::PeerEndpoint;
use orchestration_runner::runner::run_runner;
use orchestration_runner::runner_configuration::RunnerConfiguration;
use orchestration_runner::runner_loop::RunnerError;
use tokio::runtime::Runtime;
use tokio::sync::oneshot;
use tokio::task::JoinHandle;
use tokio::time::timeout;

use super::live_host::start_live_host;
use super::node_runner_server::NodeRunnerServer;

const STOP_LIMIT: Duration = Duration::from_secs(10);

#[derive(Debug)]
pub(crate) struct RunnerHandle {
    shutdown_sender: oneshot::Sender<()>,
    runner_task: JoinHandle<Result<(), RunnerError>>,
    live_host_task: JoinHandle<()>,
}

impl RunnerHandle {
    pub(crate) fn start(
        runtime: &Runtime,
        endpoint: Arc<PeerEndpoint>,
        server: NodeRunnerServer,
        configuration: RunnerConfiguration,
    ) -> Self {
        let (shutdown_sender, shutdown_receiver) = oneshot::channel();
        let shutdown = async move {
            shutdown_receiver.await.unwrap_or_default();
        };
        let server = Arc::new(server);
        let cache_root = configuration.worktree_roots.cache_root.clone();
        let live_host_task = start_live_host(
            runtime,
            endpoint,
            Arc::clone(&server),
            cache_root,
        );
        let runner_task = runtime.spawn(async move {
            run_runner(server, &configuration, shutdown).await
        });
        Self {
            shutdown_sender,
            runner_task,
            live_host_task,
        }
    }

    pub(crate) fn stop(self, runtime: &Runtime) {
        self.live_host_task.abort();
        drop(self.shutdown_sender);
        let runner_task = self.runner_task;
        let bounded_wait =
            async move { timeout(STOP_LIMIT, runner_task).await };
        let _loop_ending = runtime.block_on(bounded_wait);
    }
}
