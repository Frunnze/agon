#[cfg(feature = "app-server")]
mod server_announcement;
mod server_search;

use std::fmt::Display;

#[cfg(feature = "app-server")]
pub(crate) use server_announcement::ServerAnnouncement;
pub(crate) use server_search::LocalNetworkSearch;

use crate::node_error::NodeError;

const APP_SERVER_SERVICE_TYPE: &str = "_agentorch._tcp.local.";
const SERVER_ADDRESS_PROPERTY: &str = "server_address";

fn describe_local_network_problem(problem: &impl Display) -> NodeError {
    NodeError::LocalNetwork(problem.to_string())
}
