use proptest::prelude::*;
use serde_json::Value;

use crate::account_steps::{
    ACCOUNT_FILE_NAME, AccountRequest, NODE_CASES, SERVER_FILE_NAME,
    blank_text_strategy, has_data_file, read_error, read_status,
    start_device_and_server,
};
use crate::support::test_device::{
    TestDevice, UNREACHABLE_SERVER_ADDRESS, fail,
};

const EMPTY_SETUP_CODE: &str = "the setup code cannot be empty";
const NOT_AN_ADDRESS: &str = "is not an http, https or peer address";
const UNREACHABLE_PREFIX: &str = "could not reach the app server";
const WRONG_SETUP_CODE: &str = "the setup code is wrong";
const SETUP_CODE_SYMBOLS: &str = "[A-HJ-NP-Z2-9]{3}-[A-HJ-NP-Z2-9]{3}";

fn unparsable_address_strategy() -> impl Strategy<Value = String> {
    prop_oneof![
        "[a-z ]{0,16}",
        "ftp://[a-z]{1,8}",
        "htp://[a-z]{1,8}",
        "\\PC{0,12}",
    ]
    .prop_filter("a text no server address parser accepts", |text| {
        let lowered = text.trim().to_lowercase();
        !lowered.starts_with("http") && !lowered.starts_with("peer")
    })
}

fn wrong_setup_code_strategy() -> impl Strategy<Value = String> {
    (SETUP_CODE_SYMBOLS, SETUP_CODE_SYMBOLS).prop_map(
        |(first_half, second_half)| format!("{first_half}-{second_half}"),
    )
}

fn assert_nothing_remembered(
    device: &TestDevice,
) -> Result<(), TestCaseError> {
    prop_assert!(!has_data_file(device, ACCOUNT_FILE_NAME));
    prop_assert!(!has_data_file(device, SERVER_FILE_NAME));
    let status = read_status(device)?;
    prop_assert_eq!(&status["account"], &Value::Null);
    prop_assert_eq!(&status["server_address"], &Value::Null);
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_create_account_property_a_blank_setup_code_stays_on_the_device(
        blank_setup_code in blank_text_strategy(),
    ) {
        let (device, server) = start_device_and_server()?;
        let mut request = AccountRequest::for_server(&server)?;
        request.setup_code = blank_setup_code;

        let reply = device.send(&request.to_command());

        prop_assert_eq!(read_error(&reply), EMPTY_SETUP_CODE);
        prop_assert!(server.recorded_requests().is_empty());
        assert_nothing_remembered(&device)?;
        prop_assert_eq!(&read_status(&device)?["device_id"], &Value::Null);
    }

    #[test]
    fn test_create_account_property_an_unparsable_address_creates_nothing(
        server_address in unparsable_address_strategy(),
    ) {
        let (device, server) = start_device_and_server()?;
        let mut request = AccountRequest::for_server(&server)?;
        request.server_address = server_address;

        let reply = device.send(&request.to_command());

        prop_assert!(read_error(&reply).ends_with(NOT_AN_ADDRESS), "{reply}");
        assert_nothing_remembered(&device)?;
        prop_assert_eq!(&read_status(&device)?["device_id"], &Value::Null);
    }

    #[test]
    fn test_create_account_property_an_unreachable_server_can_be_retried(
        failed_attempts in 1_usize..3,
    ) {
        let (device, server) = start_device_and_server()?;
        let mut request = AccountRequest::for_server(&server)?;
        let reachable_address = request.server_address.clone();
        request.server_address = UNREACHABLE_SERVER_ADDRESS.to_owned();

        for _ in 0..failed_attempts {
            let reply = device.send(&request.to_command());
            let error = read_error(&reply);
            prop_assert!(error.starts_with(UNREACHABLE_PREFIX), "{reply}");
            assert_nothing_remembered(&device)?;
        }
        request.server_address = reachable_address;
        let created = device.run(&request.to_command()).map_err(fail)?;

        let status = read_status(&device)?;
        prop_assert_eq!(&status["device_id"], &created["device"]["id"]);
        let expected_address = Value::from(server.address);
        prop_assert_eq!(&status["server_address"], &expected_address);
    }

    #[test]
    fn test_create_account_property_a_wrong_setup_code_keeps_setup_open(
        wrong_setup_code in wrong_setup_code_strategy(),
    ) {
        let (device, server) = start_device_and_server()?;
        let mut request = AccountRequest::for_server(&server)?;
        let right_setup_code = request.setup_code.clone();
        prop_assume!(wrong_setup_code != right_setup_code);
        request.setup_code = wrong_setup_code;

        let refused = device.send(&request.to_command());
        let refused_error = read_error(&refused);
        assert_nothing_remembered(&device)?;
        request.setup_code = right_setup_code;
        let created = device.run(&request.to_command());

        prop_assert!(refused_error.ends_with(WRONG_SETUP_CODE), "{refused}");
        prop_assert!(created.is_ok(), "{created:?}");
        prop_assert!(has_data_file(&device, ACCOUNT_FILE_NAME));
    }
}

#[derive(Clone, Copy, Debug)]
enum SetupCodeSpelling {
    Lowercase,
    WithoutDashes,
    SpacedOut,
}

fn setup_code_spelling_strategy() -> impl Strategy<Value = SetupCodeSpelling> {
    prop_oneof![
        Just(SetupCodeSpelling::Lowercase),
        Just(SetupCodeSpelling::WithoutDashes),
        Just(SetupCodeSpelling::SpacedOut),
    ]
}

fn respell_setup_code(
    setup_code: &str,
    spelling: SetupCodeSpelling,
) -> String {
    match spelling {
        SetupCodeSpelling::Lowercase => setup_code.to_lowercase(),
        SetupCodeSpelling::WithoutDashes => setup_code.replace('-', ""),
        SetupCodeSpelling::SpacedOut => {
            format!(" {} ", setup_code.replace('-', " "))
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_create_account_property_any_spelling_of_the_setup_code_works(
        spelling in setup_code_spelling_strategy(),
    ) {
        let (device, server) = start_device_and_server()?;
        let mut request = AccountRequest::for_server(&server)?;
        request.setup_code = respell_setup_code(&request.setup_code, spelling);

        let created = device.run(&request.to_command());

        prop_assert!(created.is_ok(), "{created:?}");
        prop_assert!(has_data_file(&device, ACCOUNT_FILE_NAME));
    }
}
