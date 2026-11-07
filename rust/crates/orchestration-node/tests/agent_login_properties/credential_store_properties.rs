use std::fs;

use orchestration_node::agent_credentials::AgentCredential;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::credential_folders::{
    create_node_folder, find_credential_file, list_files_containing,
    open_credentials, replace_folder_with_a_file, write_credential_file,
};
use crate::secret_rules::{
    any_credential, any_hostile_text, any_kind, any_valid_secret,
    any_white_space_padding, expect_secret_rules,
};
use crate::support::test_device::fail;

const STORE_CASES: u32 = 24;
const LONG_RANDOM_SECRET: &str = "[A-Za-z0-9]{16,40}";
const UNKNOWN_KIND_NAME: &str = "[a-z_]{1,20}";
const LONG_UNKNOWN_KIND_NAME: &str = "[a-z]{16,24}";
const KNOWN_KIND_NAMES: [&str; 2] = ["long_lived_token", "api_key"];

fn describe_stored(credential: &AgentCredential) -> Value {
    json!({ "kind": credential.kind(), "secret": credential.secret() })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STORE_CASES))]

    #[test]
    fn test_agent_credentials_open_property_an_empty_folder_has_none(
        reads in 1_usize..4,
    ) {
        let folder = create_node_folder()?;

        let credentials = open_credentials(&folder.path)?;

        for _ in 0..reads {
            prop_assert_eq!(credentials.current(), None);
        }
    }

    #[test]
    fn test_agent_credentials_open_property_reads_a_hand_written_file(
        kind in any_kind(),
        secret in any_valid_secret(),
        padding in any_white_space_padding(),
    ) {
        let folder = create_node_folder()?;
        let padded = format!("{padding}{secret}{padding}");
        let file_text = json!({ "kind": kind, "secret": padded }).to_string();
        write_credential_file(&folder.path, &file_text)?;

        let credentials = open_credentials(&folder.path)?;

        let expected = AgentCredential::new(kind, &secret).map_err(fail)?;
        prop_assert_eq!(credentials.current(), Some(expected));
    }

    #[test]
    fn test_agent_credentials_open_property_an_unknown_field_is_refused(
        credential in any_credential(),
        field in "[a-z]{1,10}",
    ) {
        prop_assume!(field != "kind" && field != "secret");
        let folder = create_node_folder()?;
        let mut stored = describe_stored(&credential);
        stored[field] = Value::Bool(true);
        write_credential_file(&folder.path, &stored.to_string())?;

        let opened = open_credentials(&folder.path);

        prop_assert!(opened.is_err());
    }

    #[test]
    fn test_decode_property_follows_the_secret_rules(
        kind in any_kind(),
        stored_secret in any_hostile_text(),
    ) {
        let folder = create_node_folder()?;
        let file_text =
            json!({ "kind": kind, "secret": stored_secret }).to_string();
        write_credential_file(&folder.path, &file_text)?;

        let opened = open_credentials(&folder.path);

        let expected_secret = expect_secret_rules(&stored_secret).ok();
        let opened_secret = opened
            .ok()
            .and_then(|credentials| credentials.current())
            .map(|credential| credential.secret().to_owned());
        prop_assert_eq!(opened_secret, expected_secret);
    }

    #[test]
    fn test_decode_property_an_unknown_kind_is_refused(
        kind_name in UNKNOWN_KIND_NAME,
        secret in any_valid_secret(),
    ) {
        prop_assume!(!KNOWN_KIND_NAMES.contains(&kind_name.as_str()));
        let folder = create_node_folder()?;
        let file_text =
            json!({ "kind": kind_name, "secret": secret }).to_string();
        write_credential_file(&folder.path, &file_text)?;

        let opened = open_credentials(&folder.path);

        prop_assert!(opened.is_err());
    }

    #[test]
    fn test_decode_property_a_refusal_never_names_the_stored_secret(
        kind_name in LONG_UNKNOWN_KIND_NAME,
        secret in LONG_RANDOM_SECRET,
        breaker in " |\t|\n",
    ) {
        let folder = create_node_folder()?;
        let broken_secret = format!("{secret}{breaker}{secret}");
        let file_text =
            json!({ "kind": kind_name, "secret": broken_secret }).to_string();
        write_credential_file(&folder.path, &file_text)?;

        let opened = open_credentials(&folder.path);

        let Err(problem) = opened else {
            return Err(TestCaseError::fail("a broken file was opened"));
        };
        let shown = format!("{problem} {problem:?}");
        prop_assert!(!shown.contains(&secret), "{shown}");
        prop_assert!(!shown.contains(&kind_name), "{shown}");
    }

    #[test]
    fn test_encode_property_stores_only_the_kind_and_the_secret(
        credential in any_credential(),
    ) {
        let folder = create_node_folder()?;
        let credentials = open_credentials(&folder.path)?;

        credentials.keep(credential.clone()).map_err(fail)?;

        let file_text = fs::read_to_string(find_credential_file(&folder.path))
            .map_err(fail)?;
        let stored: Value = serde_json::from_str(&file_text).map_err(fail)?;
        prop_assert_eq!(stored, describe_stored(&credential));
    }

    #[test]
    fn test_encode_property_names_the_kind_like_the_app(
        credential in any_credential(),
    ) {
        let folder = create_node_folder()?;
        let credentials = open_credentials(&folder.path)?;

        credentials.keep(credential).map_err(fail)?;

        let file_text = fs::read_to_string(find_credential_file(&folder.path))
            .map_err(fail)?;
        let stored: Value = serde_json::from_str(&file_text).map_err(fail)?;
        let kind_name = stored["kind"].as_str().unwrap_or_default();
        prop_assert!(KNOWN_KIND_NAMES.contains(&kind_name), "{stored}");
    }

    #[test]
    fn test_encode_property_any_secret_survives_reopening(
        credential in any_credential(),
    ) {
        let folder = create_node_folder()?;
        open_credentials(&folder.path)?
            .keep(credential.clone())
            .map_err(fail)?;

        let reopened = open_credentials(&folder.path)?;

        prop_assert_eq!(reopened.current(), Some(credential));
    }

    #[test]
    fn test_agent_credentials_current_property_shows_a_kept_credential(
        credentials_to_keep in
            proptest::collection::vec(any_credential(), 1..5),
    ) {
        let folder = create_node_folder()?;
        let credentials = open_credentials(&folder.path)?;

        for credential in &credentials_to_keep {
            credentials.keep(credential.clone()).map_err(fail)?;
            prop_assert_eq!(credentials.current(), Some(credential.clone()));
        }

        let reopened = open_credentials(&folder.path)?;
        let last_kept = credentials_to_keep.last().cloned();
        prop_assert_eq!(reopened.current(), last_kept);
    }

    #[test]
    fn test_agent_credentials_current_property_is_a_snapshot(
        first in any_credential(),
        second in any_credential(),
    ) {
        let folder = create_node_folder()?;
        let credentials = open_credentials(&folder.path)?;
        credentials.keep(first.clone()).map_err(fail)?;

        let snapshot = credentials.current();
        credentials.keep(second).map_err(fail)?;
        credentials.forget().map_err(fail)?;

        prop_assert_eq!(snapshot, Some(first));
        prop_assert_eq!(credentials.current(), None);
    }

    #[test]
    fn test_agent_credentials_keep_property_a_failed_save_changes_nothing(
        first in any_credential(),
        second in any_credential(),
    ) {
        let folder = create_node_folder()?;
        let credentials = open_credentials(&folder.path)?;
        credentials.keep(first.clone()).map_err(fail)?;
        replace_folder_with_a_file(&folder.path)?;

        let kept = credentials.keep(second);

        prop_assert!(kept.is_err());
        prop_assert_eq!(credentials.current(), Some(first));
    }

    #[test]
    fn test_agent_credentials_keep_property_the_secret_stays_in_one_file(
        kind in any_kind(),
        secret in LONG_RANDOM_SECRET,
    ) {
        let folder = create_node_folder()?;
        let credentials = open_credentials(&folder.path)?;
        let credential = AgentCredential::new(kind, &secret).map_err(fail)?;

        credentials.keep(credential).map_err(fail)?;

        let holding_files =
            list_files_containing(&folder.path, &secret).map_err(fail)?;
        prop_assert_eq!(
            holding_files,
            vec![find_credential_file(&folder.path)]
        );
    }

    #[test]
    fn test_agent_credentials_forget_property_twice_is_harmless(
        credential in any_credential(),
        forgets in 1_usize..4,
    ) {
        let folder = create_node_folder()?;
        let credentials = open_credentials(&folder.path)?;
        credentials.keep(credential).map_err(fail)?;

        for _ in 0..=forgets {
            credentials.forget().map_err(fail)?;
        }

        prop_assert_eq!(credentials.current(), None);
        prop_assert_eq!(open_credentials(&folder.path)?.current(), None);
    }

    #[test]
    fn test_agent_credentials_forget_property_a_failed_forget_keeps_it(
        credential in any_credential(),
    ) {
        let folder = create_node_folder()?;
        let credentials = open_credentials(&folder.path)?;
        credentials.keep(credential.clone()).map_err(fail)?;
        replace_folder_with_a_file(&folder.path)?;

        let forgotten = credentials.forget();

        prop_assert!(forgotten.is_err());
        prop_assert_eq!(credentials.current(), Some(credential));
    }

    #[test]
    fn test_agent_credentials_forget_property_leaves_no_secret_on_disk(
        kind in any_kind(),
        secret in LONG_RANDOM_SECRET,
    ) {
        let folder = create_node_folder()?;
        let credentials = open_credentials(&folder.path)?;
        let credential = AgentCredential::new(kind, &secret).map_err(fail)?;
        credentials.keep(credential).map_err(fail)?;

        credentials.forget().map_err(fail)?;

        let holding_files =
            list_files_containing(&folder.path, &secret).map_err(fail)?;
        prop_assert!(holding_files.is_empty(), "{holding_files:?}");
    }
}
