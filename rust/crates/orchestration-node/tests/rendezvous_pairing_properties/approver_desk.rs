use std::sync::{Mutex, PoisonError};

use orchestration_node::node_configuration::PeerRelayChoice;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::at_once::CommandOutcome;
use crate::command_device::{BareNode, CommandDevice};
use crate::meddling_server::{EndingAnswer, JoiningRewrite, MeddlingServer};
use crate::support::pairing_steps::join_at_address;
use crate::support::test_device::{TestDevice, read_text};

pub const DESK_CASES: u32 = 3;
pub const NOT_STARTED_HERE: &str =
    "this device did not show the pairing code, start again";
pub const TRANSCRIPT_CHANGED: &str =
    "the app server changed the joining device after the words";
pub const WORDS_NOT_READY: &str =
    "the joining device has not sent its pairing nonce yet";
pub const WAITING_STATE: &str = "waiting";
pub const APPROVED_STATE: &str = "approved";
pub const REJECTED_STATE: &str = "rejected";
const NO_CODE_LEFT: &str = "no code is left to end";

#[derive(Clone, Copy, Debug)]
pub enum PairingEnding {
    Cancel,
    Reject,
    Approve,
}

impl PairingEnding {
    pub fn expected_join_state(self) -> Value {
        match self {
            Self::Cancel | Self::Reject => json!(REJECTED_STATE),
            Self::Approve => json!(APPROVED_STATE),
        }
    }
}

#[derive(Debug)]
pub struct ApproverDesk<Approver = TestDevice> {
    pub server: MeddlingServer,
    pub approver: Approver,
    pub account: Value,
}

#[derive(Debug)]
pub struct JoinedPairing {
    pub session: Value,
    pub joiner: TestDevice,
}

impl ApproverDesk<TestDevice> {
    pub fn open() -> Result<Self, String> {
        Self::open_with(TestDevice::start()?)
    }
}

impl ApproverDesk<BareNode> {
    pub fn open_bare(peer_relay: PeerRelayChoice) -> Result<Self, String> {
        Self::open_with(BareNode::open(peer_relay)?)
    }
}

impl<Approver: CommandDevice> ApproverDesk<Approver> {
    pub fn open_with(approver: Approver) -> Result<Self, String> {
        let server = MeddlingServer::start()?;
        let account = approver.run(&server.build_create_account_command()?)?;
        Ok(Self {
            server,
            approver,
            account,
        })
    }

    pub fn reset_meddling(&self) {
        self.server.answer_endings(EndingAnswer::Forwarded);
        self.server.rewrite_joining(None);
    }

    pub fn start_and_join(&self) -> Result<JoinedPairing, String> {
        let session = start_pairing(&self.approver)?;
        let joiner = self.join(&session)?;
        Ok(JoinedPairing { session, joiner })
    }

    pub fn join(&self, session: &Value) -> Result<TestDevice, String> {
        let joiner = TestDevice::start()?;
        let display_code = read_text(session, "/display_code")?;
        join_at_address(&joiner, &self.server.address, &display_code)?;
        Ok(joiner)
    }

    pub fn end(
        &self,
        device: &dyn CommandDevice,
        ending: PairingEnding,
        code: &Value,
    ) -> Result<Value, String> {
        let command = match ending {
            PairingEnding::Cancel => {
                json!({ "command": "cancel_pairing", "code": code })
            }
            PairingEnding::Reject => {
                json!({ "command": "reject_pairing", "code": code })
            }
            PairingEnding::Approve => self.build_approve_command(code),
        };
        device.run(&command)
    }

    pub fn end_next(
        &self,
        codes_left: &Mutex<Vec<Value>>,
        ending: PairingEnding,
    ) -> CommandOutcome {
        let next_code = codes_left
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .pop();
        let code = next_code.ok_or_else(|| NO_CODE_LEFT.to_owned())?;
        self.end(&self.approver, ending, &code)
    }

    pub fn approve(
        &self,
        device: &dyn CommandDevice,
        code: &Value,
    ) -> Result<Value, String> {
        device.run(&self.build_approve_command(code))
    }

    fn build_approve_command(&self, code: &Value) -> Value {
        json!({
            "command": "approve_pairing",
            "code": code,
            "workspace_ids": [self.account["workspaces"][0]["id"]],
        })
    }
}

pub fn start_pairing(device: &dyn CommandDevice) -> Result<Value, String> {
    device.run(&json!({ "command": "start_pairing" }))
}

pub fn read_request(
    device: &dyn CommandDevice,
    code: &Value,
) -> Result<Value, String> {
    device.run(&json!({ "command": "pairing_request", "code": code }))
}

pub fn read_approver_words(
    device: &dyn CommandDevice,
    code: &Value,
) -> Result<Value, String> {
    let request = read_request(device, code)?;
    Ok(request["joining"]["fingerprint_words"].clone())
}

pub fn read_joiner_status(joiner: &TestDevice) -> Result<Value, String> {
    joiner.run(&json!({ "command": "join_status" }))
}

pub fn read_joiner_words(joiner: &TestDevice) -> Result<Value, String> {
    let status = read_joiner_status(joiner)?;
    Ok(status["fingerprint_words"].clone())
}

pub fn read_join_state(joiner: &TestDevice) -> Result<Value, String> {
    let status = read_joiner_status(joiner)?;
    Ok(status["state"].clone())
}

pub fn read_status_problem(
    device: &dyn CommandDevice,
) -> Result<Value, String> {
    let status = device.run(&json!({ "command": "status" }))?;
    Ok(status["rendezvous_problem"].clone())
}

pub fn pairing_endings() -> impl Strategy<Value = PairingEnding> {
    prop_oneof![
        Just(PairingEnding::Cancel),
        Just(PairingEnding::Reject),
        Just(PairingEnding::Approve),
    ]
}

pub fn changing_rewrites() -> impl Strategy<Value = JoiningRewrite> {
    prop_oneof![
        Just(JoiningRewrite::SigningKey),
        Just(JoiningRewrite::SealingKey),
        Just(JoiningRewrite::JoinerNonce),
        Just(JoiningRewrite::ApproverNonce),
    ]
}

pub fn joiner_side_rewrites() -> impl Strategy<Value = JoiningRewrite> {
    prop_oneof![
        Just(JoiningRewrite::SigningKey),
        Just(JoiningRewrite::SealingKey),
        Just(JoiningRewrite::JoinerNonce),
    ]
}

pub fn open_desk_or_panic() -> ApproverDesk {
    match ApproverDesk::open() {
        Ok(desk) => desk,
        Err(problem) => panic!("the approver desk opens: {problem}"),
    }
}

pub fn count_words(words: &Value) -> usize {
    words.as_array().map(Vec::len).unwrap_or_default()
}
