use orchestration_core::peer_address::PeerAddress;
use orchestration_core::server_group::ServerTerm;
use orchestration_p2p::service_endpoint::ServiceEndpoint;
use orchestration_server::ServerError;
use reqwest::StatusCode;

use crate::node_error::NodeError;

pub(crate) fn describe_own_address(endpoint: &ServiceEndpoint) -> PeerAddress {
    let mut address = endpoint.peer_address();
    address.direct_addresses.sort();
    address.direct_addresses.dedup();
    address
}

pub(crate) fn describe_server_problem(problem: &ServerError) -> NodeError {
    NodeError::HostedServerFailed(problem.to_string())
}

pub(super) fn remember_term(
    known_term: &mut Option<ServerTerm>,
    seen: Option<&ServerTerm>,
) {
    let Some(seen) = seen else {
        return;
    };
    let is_higher =
        known_term.as_ref().is_none_or(|known| seen.outranks(known));
    if is_higher {
        *known_term = Some(seen.clone());
    }
}

pub(super) fn is_refusal(problem: &NodeError) -> bool {
    let forbidden = StatusCode::FORBIDDEN.as_u16();
    matches!(
        problem,
        NodeError::ServerRejected { status, .. } if *status == forbidden
    )
}

pub(super) fn is_silence(problem: &NodeError) -> bool {
    match problem {
        NodeError::ServerUnreachable(_) => true,
        NodeError::ServerRejected { status, .. } => {
            *status == StatusCode::MISDIRECTED_REQUEST.as_u16()
        }
        _ => false,
    }
}
