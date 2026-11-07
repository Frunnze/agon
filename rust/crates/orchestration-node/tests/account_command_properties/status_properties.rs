use proptest::prelude::*;
use serde_json::Value;

use crate::account_steps::{
    AccountRequest, NODE_CASES, read_status, retry_server,
    shared_fresh_device, start_device_and_server, start_device_with_account,
    valid_name_strategy,
};
use crate::support::test_device::fail;

const MOST_STATUS_READS: usize = 4;
const NO_SERVER_KEPT: &str = "none";
const NULL_WHEN_FRESH: [&str; 7] = [
    "server_address",
    "hosted_server_address",
    "device_id",
    "account",
    "pending_join",
    "rendezvous_problem",
    "runner_settings",
];
const TRAILING_SLASHES: &str = "/{0,3}";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_describe_status_property_a_fresh_device_knows_nothing(
        status_reads in 1..MOST_STATUS_READS,
    ) {
        let device = shared_fresh_device()?;

        for _ in 0..status_reads {
            let status = read_status(device)?;
            prop_assert_eq!(&status["server_reachable"], &Value::Bool(false));
            for field in NULL_WHEN_FRESH {
                prop_assert_eq!(&status[field], &Value::Null, "{}", field);
            }
            let kept = &status["app_servers"]["this_device"];
            prop_assert_eq!(kept, NO_SERVER_KEPT);
        }
    }

    #[test]
    fn test_describe_status_property_reflects_the_created_account(
        device_name in valid_name_strategy(),
        workspace_name in valid_name_strategy(),
        trailing_slashes in TRAILING_SLASHES,
    ) {
        let (device, server) = start_device_and_server()?;
        let mut request = AccountRequest::for_server(&server)?;
        request.device_name = device_name.clone();
        request.workspace_name = workspace_name.clone();
        request.server_address =
            format!("{}{trailing_slashes}", server.address);
        let created = device.run(&request.to_command()).map_err(fail)?;

        let status = read_status(&device)?;

        prop_assert_eq!(&status["server_reachable"], &Value::Bool(true));
        let expected_address = Value::from(server.address);
        prop_assert_eq!(&status["server_address"], &expected_address);
        prop_assert_eq!(&status["device_id"], &created["device"]["id"]);
        let account = &status["account"];
        prop_assert_eq!(&account["device"]["name"], &Value::from(device_name));
        let workspace = &account["workspaces"][0];
        prop_assert_eq!(&workspace["name"], &Value::from(workspace_name));
        prop_assert_eq!(&status["hosted_server_address"], &Value::Null);
        prop_assert_eq!(&status["pending_join"], &Value::Null);
    }

    #[test]
    fn test_describe_status_property_keeps_the_account_while_offline(
        status_reads in 1..MOST_STATUS_READS,
    ) {
        let (device, server, created) = start_device_with_account()?;
        let online = read_status(&device)?;
        server.stop().map_err(fail)?;

        for _ in 0..status_reads {
            let offline = read_status(&device)?;
            prop_assert_eq!(&offline["server_reachable"], &Value::Bool(false));
            let online_address = &online["server_address"];
            prop_assert_eq!(&offline["server_address"], online_address);
            prop_assert_eq!(&offline["device_id"], &created["device"]["id"]);
            prop_assert_eq!(
                &offline["account"]["workspaces"],
                &online["account"]["workspaces"]
            );
            let kept = &offline["app_servers"]["this_device"];
            prop_assert_eq!(kept, NO_SERVER_KEPT);
        }
    }

    #[test]
    fn test_describe_status_property_agrees_with_retry_server(
        stops_server in any::<bool>(),
    ) {
        let (device, server, _) = start_device_with_account()?;
        if stops_server {
            server.stop().map_err(fail)?;
        }

        let health = retry_server(&device)?;
        let status = read_status(&device)?;

        prop_assert_eq!(&health["reachable"], &Value::Bool(!stops_server));
        prop_assert_eq!(&status["server_reachable"], &health["reachable"]);
    }
}

#[derive(Clone, Copy, Debug)]
enum AddressSpelling {
    TrailingSlashes,
    UppercaseScheme,
    SurroundingSpaces,
}

fn address_spelling_strategy() -> impl Strategy<Value = AddressSpelling> {
    prop_oneof![
        Just(AddressSpelling::TrailingSlashes),
        Just(AddressSpelling::UppercaseScheme),
        Just(AddressSpelling::SurroundingSpaces),
    ]
}

fn respell_address(address: &str, spelling: AddressSpelling) -> String {
    match spelling {
        AddressSpelling::TrailingSlashes => format!("{address}//"),
        AddressSpelling::UppercaseScheme => {
            address.replacen("http://", "HTTP://", 1)
        }
        AddressSpelling::SurroundingSpaces => format!("  {address} "),
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_describe_status_property_shows_the_canonical_server_address(
        spelling in address_spelling_strategy(),
    ) {
        let (device, server) = start_device_and_server()?;
        let mut request = AccountRequest::for_server(&server)?;
        request.server_address = respell_address(&server.address, spelling);
        device.run(&request.to_command()).map_err(fail)?;

        let status = read_status(&device)?;

        let expected_address = Value::from(server.address);
        prop_assert_eq!(&status["server_address"], &expected_address);
        prop_assert_eq!(&status["server_reachable"], &Value::Bool(true));
    }
}
