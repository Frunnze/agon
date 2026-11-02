use serde_json::json;

use crate::support::command_builders::{PreparedWorkspace, prepare_workspace};
use crate::support::pairing_steps::{
    ShownWords, join_at_address, read_both_words, start_pairing,
};
use crate::support::relay_server::RelayServer;
use crate::support::test_device::{TestDevice, read_text};

const RELAY_ATTEMPTS: usize = 6;
const FINGERPRINT_WORD_COUNT: usize = 4;
const FOREIGN_ACCOUNT_ERROR: &str =
    "the approved account belongs to another device";

#[derive(Debug)]
struct RelayedAttempt {
    relay: RelayServer,
    joining_device: TestDevice,
    session: serde_json::Value,
}

fn prepared_or_panic() -> PreparedWorkspace {
    match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is prepared: {message}"),
    }
}

fn join_through_relay(
    prepared: &PreparedWorkspace,
) -> Result<RelayedAttempt, String> {
    let relay = RelayServer::start(&prepared.server.address)?;
    let joining_device = TestDevice::start()?;
    let session = start_pairing(prepared)?;
    let display_code = read_text(&session, "/display_code")?;
    join_at_address(&joining_device, &relay.address, &display_code)?;
    Ok(RelayedAttempt {
        relay,
        joining_device,
        session,
    })
}

fn read_relayed_words(
    prepared: &PreparedWorkspace,
) -> Result<ShownWords, String> {
    let attempt = join_through_relay(prepared)?;
    let shown = read_both_words(
        &prepared.device,
        &attempt.joining_device,
        &attempt.session,
    );
    drop(attempt.relay);
    shown
}

#[test]
fn test_pairing_request_property_relay_with_own_keys_shows_other_words() {
    let prepared = prepared_or_panic();

    for _attempt in 0..RELAY_ATTEMPTS {
        let shown = read_relayed_words(&prepared);

        let Ok(shown) = shown else {
            panic!("both devices show words: {shown:?}");
        };
        let approver_count = shown.approver_words.as_array().map(Vec::len);
        let joiner_count = shown.joiner_words.as_array().map(Vec::len);
        assert_eq!(approver_count, Some(FINGERPRINT_WORD_COUNT));
        assert_eq!(joiner_count, Some(FINGERPRINT_WORD_COUNT));
        assert_ne!(shown.approver_words, shown.joiner_words);
    }
}

#[test]
fn approving_a_relayed_join_never_admits_the_joining_device() {
    let prepared = prepared_or_panic();
    let Ok(attempt) = join_through_relay(&prepared) else {
        panic!("the join goes through the relay");
    };

    let approved = prepared.device.run(&json!({
        "command": "approve_pairing",
        "code": attempt.session["code"],
        "workspace_ids": [prepared.workspace_id],
    }));
    let joined = attempt
        .joining_device
        .run(&json!({ "command": "join_status" }));

    assert!(approved.is_ok(), "{approved:?}");
    let Err(problem) = joined else {
        panic!("the joining device refuses the relayed account");
    };
    assert!(problem.contains(FOREIGN_ACCOUNT_ERROR), "{problem}");
}
