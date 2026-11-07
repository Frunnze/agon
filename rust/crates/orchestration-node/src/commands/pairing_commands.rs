use orchestration_core::device::DeviceRole;
use orchestration_core::identifiers::WorkspaceId;
use orchestration_security::pairing::PairingCode;
use serde::Deserialize;
use serde_json::Value;

use super::code_joining::{CodeJoin, join_with_code};
use super::join_status::read_join_status;
use super::pairing_approval::{
    approve_pairing, read_pairing_request, start_pairing,
};
use crate::code_rendezvous::withdraw_announced_code;
use crate::command_reply::encode_reply;
use crate::node::Node;
use crate::node_error::NodeError;

pub(super) const PAIRING_COMMAND_NAMES: [&str; 7] = [
    "start_pairing",
    "pairing_request",
    "approve_pairing",
    "reject_pairing",
    "cancel_pairing",
    "join_with_code",
    "join_status",
];

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum PairingCommand {
    StartPairing {},
    PairingRequest {
        code: String,
    },
    ApprovePairing {
        code: String,
        workspace_ids: Vec<WorkspaceId>,
    },
    RejectPairing {
        code: String,
    },
    CancelPairing {
        code: String,
    },
    JoinWithCode {
        server_address: Option<String>,
        code: String,
        device_name: String,
        role: DeviceRole,
    },
    JoinStatus {},
}

pub(super) async fn handle_pairing_command(
    node: &Node,
    command: PairingCommand,
) -> Result<Value, NodeError> {
    match command {
        PairingCommand::StartPairing {} => {
            encode_reply(&start_pairing(node).await?)
        }
        PairingCommand::PairingRequest { code } => {
            encode_reply(&read_pairing_request(node, &code).await?)
        }
        PairingCommand::ApprovePairing {
            code,
            workspace_ids,
        } => {
            approve_pairing(node, &code, &workspace_ids).await?;
            Ok(Value::Null)
        }
        PairingCommand::RejectPairing { code } => {
            let pairing_code = PairingCode::parse(&code)?;
            let session = node.open_session()?;
            let client = session.client();
            client
                .reject_pairing(&String::from(pairing_code.clone()))
                .await?;
            end_pairing_here(node, &pairing_code).await;
            Ok(Value::Null)
        }
        PairingCommand::CancelPairing { code } => {
            let pairing_code = PairingCode::parse(&code)?;
            let session = node.open_session()?;
            let client = session.client();
            let cancelled = client
                .cancel_pairing(&String::from(pairing_code.clone()))
                .await;
            end_pairing_here(node, &pairing_code).await;
            cancelled?;
            Ok(Value::Null)
        }
        PairingCommand::JoinWithCode {
            server_address,
            code,
            device_name,
            role,
        } => {
            let join = CodeJoin {
                server_address,
                code,
                device_name,
                role,
            };
            encode_reply(&join_with_code(node, join).await?)
        }
        PairingCommand::JoinStatus {} => {
            encode_reply(&read_join_status(node).await?)
        }
    }
}

pub(super) async fn end_pairing_here(node: &Node, code: &PairingCode) {
    node.approver_pairings().forget(code);
    withdraw_announced_code(node, code).await;
}
