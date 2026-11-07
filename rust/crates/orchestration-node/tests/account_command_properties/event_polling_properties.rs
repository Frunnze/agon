use proptest::prelude::*;
use serde_json::Value;

use crate::account_steps::{
    NODE_CASES, PARSING_CASES, poll_events, read_error, shared_fresh_device,
    start_device_with_account,
};
use crate::support::test_device::fail;

const NO_ACCOUNT: &str = "this device has no account yet";
const MOST_CURSORS: usize = 4;
const CURSOR_REACH_PAST_LATEST: u64 = 3;

fn read_sequences(events: &Value) -> Vec<u64> {
    let mut sequences = Vec::new();
    let notifications = events["notifications"].as_array().cloned();
    for notification in notifications.unwrap_or_default() {
        sequences.push(notification["sequence"].as_u64().unwrap_or(0));
    }
    sequences
}

fn read_latest_sequence(events: &Value) -> Result<u64, TestCaseError> {
    let latest = events["latest_sequence"].as_u64();
    latest.ok_or_else(|| fail(format!("no latest sequence in {events}")))
}

fn cursor_seeds_strategy() -> impl Strategy<Value = Vec<u64>> {
    proptest::collection::vec(any::<u64>(), 1..MOST_CURSORS)
}

fn place_cursor(latest_sequence: u64, cursor_seed: u64) -> u64 {
    let cursor_choices = latest_sequence + CURSOR_REACH_PAST_LATEST + 1;
    cursor_seed % cursor_choices
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PARSING_CASES))]

    #[test]
    fn test_account_command_poll_events_property_needs_an_account(
        after in any::<u64>(),
    ) {
        let device = shared_fresh_device()?;

        let reply = device.send(&serde_json::json!({
            "command": "poll_events",
            "after": after,
        }));

        prop_assert_eq!(read_error(&reply), NO_ACCOUNT);
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASES))]

    #[test]
    fn test_account_command_poll_events_property_lists_only_newer_changes(
        cursor_seeds in cursor_seeds_strategy(),
    ) {
        let (device, _server, _) = start_device_with_account()?;
        let latest = read_latest_sequence(&poll_events(&device, 0)?)?;

        for cursor_seed in cursor_seeds {
            let after = place_cursor(latest, cursor_seed);
            let events = poll_events(&device, after)?;
            let sequences = read_sequences(&events);
            let latest_now = read_latest_sequence(&events)?;
            for pair in sequences.windows(2) {
                prop_assert!(pair[0] < pair[1], "{events}");
            }
            for sequence in sequences {
                prop_assert!(after < sequence && sequence <= latest_now);
            }
        }
    }

    #[test]
    fn test_account_command_poll_events_property_agrees_with_the_full_feed(
        cursor_seeds in cursor_seeds_strategy(),
    ) {
        let (device, _server, _) = start_device_with_account()?;
        let full_feed = poll_events(&device, 0)?;
        let latest = read_latest_sequence(&full_feed)?;

        for cursor_seed in cursor_seeds {
            let after = place_cursor(latest, cursor_seed);
            let events = poll_events(&device, after)?;
            let mut expected = Vec::new();
            let all_notifications =
                full_feed["notifications"].as_array().cloned();
            for notification in all_notifications.unwrap_or_default() {
                let sequence = notification["sequence"].as_u64().unwrap_or(0);
                if sequence > after {
                    expected.push(notification);
                }
            }
            prop_assert_eq!(&events["notifications"], &Value::from(expected));
            prop_assert_eq!(read_latest_sequence(&events)?, latest);
        }
    }

    #[test]
    fn test_account_command_poll_events_property_a_cursor_ahead_gets_nothing(
        distance_ahead in 1..u64::MAX / 2,
    ) {
        let (device, _server, _) = start_device_with_account()?;
        let latest = read_latest_sequence(&poll_events(&device, 0)?)?;

        let ahead_cursor = latest.saturating_add(distance_ahead);
        let events = poll_events(&device, ahead_cursor)?;

        prop_assert!(read_sequences(&events).is_empty(), "{events}");
        prop_assert_eq!(read_latest_sequence(&events)?, latest);
    }
}
