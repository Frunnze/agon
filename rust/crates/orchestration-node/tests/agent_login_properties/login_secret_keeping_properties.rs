use proptest::prelude::*;

use crate::credential_folders::list_files_containing;
use crate::login_steps::{
    API_KEY_NAME, CONTAINER_PLACE, CREDENTIAL_FILE_NAME,
    CREDENTIAL_KIND_FIELD, LOGIN_CASES, TOKEN_START, finish_login,
    read_status_field, save_api_key, start_nodes,
};
use crate::support::login_runner::{LoginRunner, find_text_in_folder};
use crate::support::test_device::fail;

const LONG_LOGIN_CODE: &str = "[A-Za-z0-9]{24,40}";
const LONG_API_KEY: &str = "sk-ant-api03-[A-Za-z0-9]{24,40}";

fn is_sent_to_the_server(nodes: &LoginRunner, secret: &str) -> bool {
    let recorded_requests = nodes.server.recorded_requests();
    for request in recorded_requests {
        if String::from_utf8_lossy(&request.body).contains(secret) {
            return true;
        }
    }
    false
}

fn check_secret_kept_only_locally(
    nodes: &LoginRunner,
    secret: &str,
) -> Result<(), TestCaseError> {
    let holding_files =
        list_files_containing(nodes.data.path(), secret).map_err(fail)?;
    let credential_path = nodes.data.path().join(CREDENTIAL_FILE_NAME);
    prop_assert_eq!(holding_files, vec![credential_path]);
    let is_in_records =
        find_text_in_folder(nodes.records.path(), secret).map_err(fail)?;
    prop_assert!(!is_in_records);
    let server_state = nodes.server.read_stored_state().map_err(fail)?;
    prop_assert!(!server_state.contains(secret));
    prop_assert!(!is_sent_to_the_server(nodes, secret));
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LOGIN_CASES))]

    #[test]
    fn test_settle_property_the_token_is_kept_only_in_the_data_folder(
        code in LONG_LOGIN_CODE,
    ) {
        let nodes = start_nodes()?;

        finish_login(&nodes, CONTAINER_PLACE, &code)?;

        let token = format!("{TOKEN_START}{code}");
        check_secret_kept_only_locally(&nodes, &token)?;
        prop_assert!(!is_sent_to_the_server(&nodes, &code));
    }

    #[test]
    fn test_agent_credentials_keep_property_a_key_is_kept_only_locally(
        api_key in LONG_API_KEY,
    ) {
        let nodes = start_nodes()?;

        save_api_key(&nodes, &api_key).map_err(fail)?;

        let credential = read_status_field(&nodes, CREDENTIAL_KIND_FIELD)?;
        prop_assert_eq!(credential, API_KEY_NAME);
        check_secret_kept_only_locally(&nodes, &api_key)?;
    }

    #[test]
    fn test_agent_credential_new_property_a_refused_key_is_never_stored(
        start in LONG_LOGIN_CODE,
        end in LONG_LOGIN_CODE,
    ) {
        let nodes = start_nodes()?;
        let refused_key = format!("{start} {end}");

        let saved = save_api_key(&nodes, &refused_key);

        prop_assert!(saved.is_err());
        let holding_files =
            list_files_containing(nodes.data.path(), &start).map_err(fail)?;
        prop_assert!(holding_files.is_empty(), "{holding_files:?}");
        let problem = saved.err().unwrap_or_default();
        prop_assert!(!problem.contains(&start), "{problem}");
    }
}
