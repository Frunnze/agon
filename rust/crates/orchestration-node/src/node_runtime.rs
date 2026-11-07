use std::sync::Arc;
use std::time::Duration;

use tokio::runtime::Runtime;
use tokio::time::timeout;

#[cfg(feature = "app-server")]
use crate::app_server_hosting::{
    restart_recorded_app_server, stop_hosted_app_server,
};
use crate::command_reply::render_error_reply;
#[cfg(feature = "runner")]
use crate::command_reply::render_node_error_reply;
use crate::commands::dispatch_command;
use crate::node::Node;
use crate::node_configuration::NodeConfiguration;
use crate::node_error::NodeError;
use crate::peer_side::{PeerSide, start_announcer};
#[cfg(feature = "runner")]
use crate::runner_bridge::RunnerLauncher;
#[cfg(not(feature = "runner"))]
use crate::runner_settings::RunnerChoice;

const ENDPOINT_CLOSE_LIMIT: Duration = Duration::from_secs(3);

#[derive(Debug)]
pub struct NodeRuntime {
    runtime: Runtime,
    node: Arc<Node>,
    peer_side: Arc<PeerSide>,
    #[cfg(feature = "runner")]
    runner_launcher: RunnerLauncher,
}

impl NodeRuntime {
    pub fn start(configuration_json: &str) -> Result<Self, NodeError> {
        let configuration = NodeConfiguration::from_json(configuration_json)?;
        Self::start_configured(&configuration)
    }

    pub fn start_configured(
        configuration: &NodeConfiguration,
    ) -> Result<Self, NodeError> {
        #[cfg(not(feature = "runner"))]
        if matches!(configuration.runner, Some(RunnerChoice::Given(_))) {
            return Err(NodeError::RunnerUnavailable);
        }
        #[cfg(feature = "runner")]
        let runner_launcher = RunnerLauncher::prepare(
            configuration.runner.as_ref(),
            &configuration.data_directory,
        )?;
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .map_err(|error| NodeError::Startup(error.to_string()))?;
        let node = Arc::new(Node::open(configuration)?);
        #[cfg(feature = "app-server")]
        restart_off_the_calling_thread(&runtime, &node)?;
        #[cfg(not(feature = "app-server"))]
        if node.device_files().load_hosted_server()?.is_some() {
            return Err(NodeError::HostingUnavailable);
        }
        let peer_side = Arc::new(PeerSide::bind(
            &runtime,
            &node,
            &configuration.peer_relay,
        )?);
        node.attach_peer_side(Arc::clone(&peer_side));
        start_announcer(&runtime, Arc::clone(&node), Arc::clone(&peer_side));

        #[cfg(feature = "runner")]
        runner_launcher.start_when_ready(&runtime, &node)?;
        Ok(Self {
            runtime,
            node,
            peer_side,
            #[cfg(feature = "runner")]
            runner_launcher,
        })
    }

    #[must_use]
    pub fn handle_command(&self, command_json: &str) -> String {
        let node = Arc::clone(&self.node);
        let command_text = command_json.to_owned();
        let dispatching = self.runtime.spawn(async move {
            dispatch_command(&node, &command_text).await
        });
        let reply = match self.runtime.block_on(dispatching) {
            Ok(reply) => reply,
            Err(problem) => render_error_reply(&problem.to_string()),
        };
        #[cfg(feature = "runner")]
        if let Err(problem) = self
            .runner_launcher
            .start_when_ready(&self.runtime, &self.node)
        {
            return render_node_error_reply(&problem);
        }
        reply
    }
}

impl Drop for NodeRuntime {
    fn drop(&mut self) {
        #[cfg(feature = "runner")]
        self.runner_launcher.stop(&self.runtime);
        let endpoint = Arc::clone(&self.peer_side.endpoint);
        let node = Arc::clone(&self.node);
        let closing = async move {
            #[cfg(feature = "app-server")]
            stop_hosted_app_server(&node).await;
            tokio::join!(endpoint.close(), node.server_dialer().close());
        };
        let bounded_closing =
            async move { timeout(ENDPOINT_CLOSE_LIMIT, closing).await };
        let _endpoints_closed = self.runtime.block_on(bounded_closing);
    }
}

#[cfg(feature = "app-server")]
fn restart_off_the_calling_thread(
    runtime: &Runtime,
    node: &Arc<Node>,
) -> Result<(), NodeError> {
    let restarting_node = Arc::clone(node);
    let restarting = runtime.spawn(async move {
        restart_recorded_app_server(&restarting_node).await
    });
    let restarted = runtime
        .block_on(restarting)
        .map_err(|problem| NodeError::Startup(problem.to_string()))?;
    if let Err(problem) = restarted {
        node.record_hosting_problem(&problem);
    }
    Ok(())
}
