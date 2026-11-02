use std::io;
use std::net::{Ipv4Addr, TcpListener};

use crate::node_error::NodeError;

pub(super) fn bind_hosted_listener(
    port: u16,
) -> Result<TcpListener, NodeError> {
    let listener = TcpListener::bind((Ipv4Addr::LOCALHOST, port))
        .map_err(|problem| describe_unavailable_port(port, &problem))?;
    listener
        .set_nonblocking(true)
        .map_err(|problem| describe_unavailable_port(port, &problem))?;
    Ok(listener)
}

fn describe_unavailable_port(port: u16, problem: &io::Error) -> NodeError {
    NodeError::AppServerPortUnavailable {
        port,
        problem: problem.to_string(),
    }
}
