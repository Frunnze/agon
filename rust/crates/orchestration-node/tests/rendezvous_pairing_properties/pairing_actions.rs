use proptest::prelude::*;
use serde_json::{Value, json};

use crate::approver_desk::{
    ApproverDesk, read_request, read_status_problem, start_pairing,
};
use crate::command_device::CommandDevice;

pub const NO_PEER_ENDPOINT: &str = "this node has no peer endpoint";
const MOST_ACTIONS: usize = 5;

#[derive(Clone, Copy, Debug)]
pub enum PairingAction {
    Start,
    CancelLatest,
    ReadLatestRequest,
    ReadStatus,
}

#[derive(Debug)]
pub struct PairingObservation {
    pub started_session: Option<Value>,
    pub status_problem: Value,
}

pub fn pairing_actions() -> impl Strategy<Value = Vec<PairingAction>> {
    let action = prop_oneof![
        Just(PairingAction::Start),
        Just(PairingAction::CancelLatest),
        Just(PairingAction::ReadLatestRequest),
        Just(PairingAction::ReadStatus),
    ];
    proptest::collection::vec(action, 1..=MOST_ACTIONS)
}

pub fn observe_pairing_actions<Approver: CommandDevice>(
    desk: &ApproverDesk<Approver>,
    actions: &[PairingAction],
) -> Result<Vec<PairingObservation>, String> {
    let mut showing_code: Option<Value> = None;
    let mut observations = Vec::new();
    for action in actions {
        let started_session = match action {
            PairingAction::Start => Some(start_pairing(&desk.approver)?),
            PairingAction::CancelLatest => {
                cancel_showing(&desk.approver, showing_code.take())?;
                None
            }
            PairingAction::ReadLatestRequest => {
                if let Some(code) = &showing_code {
                    read_request(&desk.approver, code)?;
                }
                None
            }
            PairingAction::ReadStatus => None,
        };
        if let Some(session) = &started_session {
            showing_code = Some(session["code"].clone());
        }

        observations.push(PairingObservation {
            started_session,
            status_problem: read_status_problem(&desk.approver)?,
        });
    }
    Ok(observations)
}

fn cancel_showing(
    approver: &dyn CommandDevice,
    showing_code: Option<Value>,
) -> Result<(), String> {
    let Some(code) = showing_code else {
        return Ok(());
    };
    approver.run(&json!({ "command": "cancel_pairing", "code": code }))?;
    Ok(())
}
