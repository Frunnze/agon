use orchestration_node::server_address::ServerAddress;
use serde_json::{Value, json};

use crate::support::hosting_steps::{NO_SERVER_ACCEPTED_CODE, read_status};
use crate::support::pairing_steps::{
    approve_into_first_workspace, join_on_local_network,
};
use crate::support::public_board_turn::wait_for_public_board_turn;
use crate::support::rendezvous_lookup::{
    generate_unissued_code, look_up_code,
};
use crate::support::test_device::{TestDevice, read_text};
use crate::support::test_server::TestServer;

#[derive(Debug)]
struct ReachableWorkspace {
    server: TestServer,
    device: TestDevice,
    account: Value,
}

fn prepare_workspace_with(device: TestDevice) -> ReachableWorkspace {
    let Ok(server) = TestServer::start() else {
        panic!("the app server starts");
    };
    let account = device.create_account(&server, "acme");
    let Ok(account) = account else {
        panic!("the account is created: {account:?}");
    };
    ReachableWorkspace {
        server,
        device,
        account,
    }
}

fn start_device_crossing_networks() -> TestDevice {
    match TestDevice::start_crossing_networks() {
        Ok(device) => device,
        Err(problem) => panic!("the device starts: {problem}"),
    }
}

fn start_pairing_or_panic(device: &TestDevice) -> (Value, String) {
    let session = device.run(&json!({ "command": "start_pairing" }));
    let Ok(session) = session else {
        panic!("pairing starts: {session:?}");
    };
    let Ok(code) = read_text(&session, "/display_code") else {
        panic!("the session shows a code");
    };
    (session, code)
}

#[test]
fn test_join_with_code_property_the_code_alone_joins_from_another_network() {
    let _board_turn = wait_for_public_board_turn();
    let workspace = prepare_workspace_with(start_device_crossing_networks());
    let joining = start_device_crossing_networks();
    let (session, code) = start_pairing_or_panic(&workspace.device);
    let starting_status = read_status(&workspace.device);

    let joined = join_on_local_network(&joining, &code);
    let approved = approve_into_first_workspace(
        &workspace.device,
        &session,
        &workspace.account,
    );
    let join_status = joining.run(&json!({ "command": "join_status" }));
    let joined_status = read_status(&joining);
    let record_after_use = look_up_code(&code);

    let rendezvous_problem =
        starting_status.map(|status| status["rendezvous_problem"].clone());
    assert_eq!(rendezvous_problem, Ok(Value::Null));
    assert!(joined.is_ok(), "{joined:?}");
    assert!(approved.is_ok(), "{approved:?}");
    let state = join_status.map(|status| status["state"].clone());
    assert_eq!(state, Ok(json!("approved")));
    let joined_address =
        joined_status.and_then(|status| read_text(&status, "/server_address"));
    assert_eq!(joined_address, Ok(workspace.server.address.clone()));
    assert_eq!(record_after_use, Err(NO_SERVER_ACCEPTED_CODE.to_owned()));
}

#[test]
fn test_join_with_code_property_a_wrong_code_finds_no_server() {
    let _board_turn = wait_for_public_board_turn();
    let joining = start_device_crossing_networks();
    let Ok(unissued_code) = generate_unissued_code() else {
        panic!("a code is generated");
    };

    let joined = join_on_local_network(&joining, &unissued_code);

    assert_eq!(joined, Err(NO_SERVER_ACCEPTED_CODE.to_owned()));
}

#[test]
fn test_cancel_pairing_property_the_published_record_is_withdrawn() {
    let _board_turn = wait_for_public_board_turn();
    let workspace = prepare_workspace_with(start_device_crossing_networks());
    let (session, code) = start_pairing_or_panic(&workspace.device);

    let record_before = look_up_code(&code);
    let cancelled = workspace.device.run(&json!({
        "command": "cancel_pairing",
        "code": session["code"],
    }));
    let record_after = look_up_code(&code);

    let expected = ServerAddress::Web(workspace.server.address.clone());
    assert_eq!(record_before, Ok(expected));
    assert_eq!(cancelled, Ok(Value::Null));
    assert_eq!(record_after, Err(NO_SERVER_ACCEPTED_CODE.to_owned()));
}

#[test]
fn test_start_pairing_property_a_local_only_device_publishes_nothing() {
    let _board_turn = wait_for_public_board_turn();
    let Ok(local_device) = TestDevice::start() else {
        panic!("the device starts");
    };
    let workspace = prepare_workspace_with(local_device);
    let (_session, code) = start_pairing_or_panic(&workspace.device);

    let record = look_up_code(&code);

    assert_eq!(record, Err(NO_SERVER_ACCEPTED_CODE.to_owned()));
}
