use std::fs;
use std::path::PathBuf;

use proptest::prelude::*;
use serde_json::Value;

use crate::account_steps::{
    NODE_CASES, SERVER_GROUP_FILE_NAME, has_data_file, poll_events,
    read_status, start_device_with_account,
};
use crate::support::command_builders::create_project_command;
use crate::support::hosting_steps::{create_hosted_account, pick_free_port};
use crate::support::test_device::{TestDevice, fail, read_text};

const HOSTING_CASES: u32 = 2;
const GROUP_CHANGE_TOPIC_NAMES: [&str; 2] = ["server_group", "devices"];
const MOST_POLLS: usize = 3;

fn read_topic_names(events: &Value) -> Vec<String> {
    let mut topic_names = Vec::new();
    let notifications = events["notifications"].as_array().cloned();
    for notification in notifications.unwrap_or_default() {
        let topic_name = notification["topic"]["topic"].as_str();
        topic_names.push(topic_name.unwrap_or_default().to_owned());
    }
    topic_names
}

fn has_group_change(events: &Value) -> bool {
    for topic_name in read_topic_names(events) {
        if GROUP_CHANGE_TOPIC_NAMES.contains(&topic_name.as_str()) {
            return true;
        }
    }
    false
}

fn stored_group_path(device: &TestDevice) -> PathBuf {
    device.data_directory.path().join(SERVER_GROUP_FILE_NAME)
}

fn start_hosting_device_without_stored_group()
-> Result<TestDevice, TestCaseError> {
    let port = pick_free_port().map_err(fail)?;
    let device = TestDevice::start_hosting_on(port).map_err(fail)?;
    create_hosted_account(&device).map_err(fail)?;
    fs::remove_file(stored_group_path(&device)).map_err(fail)?;
    Ok(device)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HOSTING_CASES))]

    #[test]
    fn test_group_change_topics_property_a_group_change_restores_the_group(
        polls in 1..MOST_POLLS,
    ) {
        let device = start_hosting_device_without_stored_group()?;

        for _ in 0..polls {
            let events = poll_events(&device, 0)?;
            prop_assert!(has_group_change(&events), "{events}");
            prop_assert!(has_data_file(&device, SERVER_GROUP_FILE_NAME));
        }

        let polled_group = fs::read(stored_group_path(&device)).map_err(fail)?;
        read_status(&device)?;
        let status_group = fs::read(stored_group_path(&device)).map_err(fail)?;
        prop_assert_eq!(status_group, polled_group);
    }

    #[test]
    fn test_group_change_topics_property_no_new_change_leaves_the_group_out(
        polls in 1..MOST_POLLS,
    ) {
        let device = start_hosting_device_without_stored_group()?;

        for _ in 0..polls {
            let events = poll_events(&device, u64::MAX)?;
            prop_assert!(!has_group_change(&events), "{events}");
        }

        prop_assert!(!has_data_file(&device, SERVER_GROUP_FILE_NAME));
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_group_change_topics_property_other_changes_leave_the_group_out(
        polls in 1..MOST_POLLS,
    ) {
        let (device, _server, created) = start_device_with_account()?;
        let workspace_id =
            read_text(&created, "/workspaces/0/id").map_err(fail)?;
        let after_account = poll_events(&device, u64::MAX)?;
        let latest = after_account["latest_sequence"].as_u64();
        device.run(&create_project_command(&workspace_id)).map_err(fail)?;

        for _ in 0..polls {
            let events = poll_events(&device, latest.unwrap_or(0))?;
            prop_assert!(!read_topic_names(&events).is_empty(), "{events}");
            prop_assert!(!has_group_change(&events), "{events}");
        }

        prop_assert!(!has_data_file(&device, SERVER_GROUP_FILE_NAME));
    }
}
