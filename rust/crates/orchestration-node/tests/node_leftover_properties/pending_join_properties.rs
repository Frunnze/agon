use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use serde_json::{Value, json};

use crate::support::hosting_steps::{
    create_hosted_account, pick_free_port, read_status,
};
use crate::support::pairing_steps::{
    approve_into_first_workspace, join_at_address,
};
use crate::support::test_device::{TestDevice, fail, read_text};
use crate::support::test_server::TestServer;

const PENDING_JOIN_CASES: u32 = 3;
const PENDING_JOIN_FILE_NAME: &str = "pending-join.json";
const NO_PENDING_JOIN: &str = "no pairing request from this device is waiting";
const APPROVER_WORKSPACE: &str = "acme";
const WORKSPACE_PATTERN: &str = "[a-z][a-z0-9-]{0,12}";
const WRONG_SETUP_CODE_PATTERN: &str = "[A-Z]{3}-[A-Z]{3}";

#[derive(Debug)]
struct AbandonedJoin {
    approver_server: TestServer,
    approver: TestDevice,
    approver_account: Value,
    session: Value,
    join_view: Value,
}

fn start_abandoned_join(
    joiner: &TestDevice,
) -> Result<AbandonedJoin, TestCaseError> {
    let approver_server = TestServer::start().map_err(fail)?;
    let approver = TestDevice::start().map_err(fail)?;
    let approver_account = approver
        .create_account(&approver_server, APPROVER_WORKSPACE)
        .map_err(fail)?;
    let session = approver
        .run(&json!({ "command": "start_pairing" }))
        .map_err(fail)?;
    let display_code = read_text(&session, "/display_code").map_err(fail)?;
    let join_view =
        join_at_address(joiner, &approver_server.address, &display_code)
            .map_err(fail)?;
    Ok(AbandonedJoin {
        approver_server,
        approver,
        approver_account,
        session,
        join_view,
    })
}

fn has_pending_join_file(device: &TestDevice) -> bool {
    let data_directory = device.data_directory.path();
    data_directory.join(PENDING_JOIN_FILE_NAME).exists()
}

fn read_first_workspace_name(status: &Value) -> Value {
    status["account"]["workspaces"][0]["name"].clone()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PENDING_JOIN_CASES))]

    #[test]
    fn test_create_account_property_a_new_account_shows_no_pending_join(
        workspace_name in WORKSPACE_PATTERN,
    ) {
        let joiner = TestDevice::start().map_err(fail)?;
        let abandoned = start_abandoned_join(&joiner)?;
        let new_server = TestServer::start().map_err(fail)?;
        let status_before = read_status(&joiner).map_err(fail)?;

        joiner
            .create_account(&new_server, &workspace_name)
            .map_err(fail)?;
        let status_after = read_status(&joiner).map_err(fail)?;

        prop_assert_eq!(&status_before["pending_join"], &abandoned.join_view);
        prop_assert_eq!(&status_after["pending_join"], &Value::Null);
        prop_assert!(!has_pending_join_file(&joiner));
        prop_assert_eq!(
            read_first_workspace_name(&status_after),
            json!(workspace_name)
        );
    }

    #[test]
    fn test_create_account_property_a_late_approval_keeps_the_new_account(
        workspace_name in WORKSPACE_PATTERN,
    ) {
        let joiner = TestDevice::start().map_err(fail)?;
        let abandoned = start_abandoned_join(&joiner)?;
        let new_server = TestServer::start().map_err(fail)?;
        joiner
            .create_account(&new_server, &workspace_name)
            .map_err(fail)?;

        approve_into_first_workspace(
            &abandoned.approver,
            &abandoned.session,
            &abandoned.approver_account,
        )
        .map_err(fail)?;
        let followed = joiner.run(&json!({ "command": "join_status" }));
        let status = read_status(&joiner).map_err(fail)?;

        prop_assert_eq!(followed, Err(NO_PENDING_JOIN.to_owned()));
        prop_assert_eq!(
            read_first_workspace_name(&status),
            json!(workspace_name)
        );
        prop_assert_eq!(&status["server_address"], &json!(new_server.address));
        prop_assert!(abandoned.approver_server.is_running());
    }

    #[test]
    fn test_create_account_property_a_refused_creation_keeps_the_join(
        wrong_setup_code in WRONG_SETUP_CODE_PATTERN,
    ) {
        let joiner = TestDevice::start().map_err(fail)?;
        let abandoned = start_abandoned_join(&joiner)?;
        let new_server = TestServer::start().map_err(fail)?;

        let refused = joiner.run(&json!({
            "command": "create_account",
            "server_address": new_server.address,
            "setup_code": wrong_setup_code,
            "device_name": "air-laptop",
            "role": "client",
            "workspace_name": "home",
        }));
        let status = read_status(&joiner).map_err(fail)?;

        prop_assert!(refused.is_err(), "{:?}", refused);
        prop_assert_eq!(&status["pending_join"], &abandoned.join_view);
        prop_assert_eq!(&status["account"], &Value::Null);
        prop_assert!(has_pending_join_file(&joiner));
    }

    #[test]
    fn test_create_hosted_account_property_hosting_shows_no_pending_join(
        status_reads in 1_usize..3,
    ) {
        let port = pick_free_port().map_err(fail)?;
        let joiner = TestDevice::start_hosting_on(port).map_err(fail)?;
        start_abandoned_join(&joiner)?;

        create_hosted_account(&joiner).map_err(fail)?;

        for _ in 0..status_reads {
            let status = read_status(&joiner).map_err(fail)?;
            prop_assert_eq!(&status["pending_join"], &Value::Null);
            prop_assert!(status["account"].is_object());
        }
        prop_assert!(!has_pending_join_file(&joiner));
    }
}
