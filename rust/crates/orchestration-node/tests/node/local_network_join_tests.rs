use serde_json::json;

use crate::support::hosting_steps::{
    HostingDevice, NO_SERVER_ACCEPTED_CODE, read_hosted_address,
    read_server_identity, read_status, start_hosting_device,
};
use crate::support::pairing_steps::{
    approve_into_first_workspace, join_at_address, join_on_local_network,
};
use crate::support::test_device::{TestDevice, read_text};

const UNISSUED_CODE: &str = "ZZZ-ZZZ";
const NO_PENDING_JOIN: &str = "no pairing request from this device is waiting";

fn start_hosting_and_joining() -> (HostingDevice, TestDevice) {
    let hosting = start_hosting_device();
    let Ok(hosting) = hosting else {
        panic!("the device hosts the app server: {hosting:?}");
    };
    let Ok(joining) = TestDevice::start() else {
        panic!("the joining device starts");
    };
    (hosting, joining)
}

#[test]
fn test_join_with_code_property_the_code_alone_finds_the_hosted_server() {
    let (hosting, joining) = start_hosting_and_joining();
    let Ok(session) =
        hosting.device.run(&json!({ "command": "start_pairing" }))
    else {
        panic!("pairing starts");
    };
    let Ok(code) = read_text(&session, "/display_code") else {
        panic!("the session shows a code");
    };

    let joined = join_on_local_network(&joining, &code);
    let approved = approve_into_first_workspace(
        &hosting.device,
        &session,
        &hosting.account,
    );
    let join_status = joining.run(&json!({ "command": "join_status" }));
    let joined_status = read_status(&joining);

    assert!(joined.is_ok(), "{joined:?}");
    assert!(approved.is_ok(), "{approved:?}");
    let state = join_status.map(|status| status["state"].clone());
    assert_eq!(state, Ok(json!("approved")));
    let joined_address =
        joined_status.and_then(|status| read_text(&status, "/server_address"));
    let hosted_address = read_hosted_address(&hosting.device);
    assert_eq!(
        read_server_identity(joined_address),
        read_server_identity(hosted_address)
    );
}

#[test]
fn test_join_with_code_property_an_unissued_code_gives_the_defined_error() {
    let (_hosting, joining) = start_hosting_and_joining();

    let joined = join_on_local_network(&joining, UNISSUED_CODE);
    let join_status = joining.run(&json!({ "command": "join_status" }));

    assert_eq!(joined, Err(NO_SERVER_ACCEPTED_CODE.to_owned()));
    assert_eq!(join_status, Err(NO_PENDING_JOIN.to_owned()));
}

#[test]
fn test_join_with_code_property_an_explicit_address_still_joins() {
    let (hosting, joining) = start_hosting_and_joining();
    let Ok(address) = read_hosted_address(&hosting.device) else {
        panic!("the hosted address is known");
    };
    let Ok(session) =
        hosting.device.run(&json!({ "command": "start_pairing" }))
    else {
        panic!("pairing starts");
    };
    let Ok(code) = read_text(&session, "/display_code") else {
        panic!("the session shows a code");
    };

    let joined = join_at_address(&joining, &address, &code);
    let approved = approve_into_first_workspace(
        &hosting.device,
        &session,
        &hosting.account,
    );
    let join_status = joining.run(&json!({ "command": "join_status" }));

    assert!(joined.is_ok(), "{joined:?}");
    assert!(approved.is_ok(), "{approved:?}");
    let state = join_status.map(|status| status["state"].clone());
    assert_eq!(state, Ok(json!("approved")));
}
