use std::time::Duration;

use orchestration_api::updates::{ChangeTopic, EventsResponse};
use proptest::prelude::*;

use crate::fixtures::{create_account, create_project};
use crate::operations::{
    SETUP_CHANGE_COUNT, count_changes, operation_strategy, perform_operation,
};
use crate::test_client::{TestServer, block_on};

const PATIENT_LONG_POLL_TIMEOUT: Duration = Duration::from_secs(5);
const DELAY_BEFORE_CHANGE: Duration = Duration::from_millis(20);

fn events_path(after: u64) -> String {
    format!("/events?after={after}")
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(16))]

    #[test]
    fn test_poll_events_property_sequence_numbers_strictly_increase(
        operations in proptest::collection::vec(operation_strategy(), 0..10),
    ) {
        let test = TestServer::start();
        let events: EventsResponse = block_on(async {
            let account = create_account(&test).await;
            let project = create_project(&test, &account).await;
            for operation in &operations {
                perform_operation(&test, &account, &project, *operation).await;
            }
            test.get(&account.owner, &events_path(0)).await.json()
        });

        let expected_count = SETUP_CHANGE_COUNT + count_changes(&operations);
        prop_assert_eq!(events.notifications.len(), expected_count);
        for pair in events.notifications.windows(2) {
            prop_assert!(pair[0].sequence < pair[1].sequence);
        }
        let last_notification = events.notifications.last();
        let last_sequence =
            last_notification.map(|notification| notification.sequence);
        prop_assert_eq!(last_sequence, Some(events.latest_sequence));
    }

    #[test]
    fn test_poll_events_property_returns_only_newer_notifications(
        operations in proptest::collection::vec(operation_strategy(), 0..8),
        after in 0_u64..12,
    ) {
        let test = TestServer::start();
        let events: EventsResponse = block_on(async {
            let account = create_account(&test).await;
            let project = create_project(&test, &account).await;
            for operation in &operations {
                perform_operation(&test, &account, &project, *operation).await;
            }
            test.get(&account.owner, &events_path(after)).await.json()
        });

        for notification in &events.notifications {
            prop_assert!(notification.sequence > after);
        }
    }
}

#[test]
fn a_waiting_poll_returns_empty_after_the_timeout() {
    let test = TestServer::start();
    let events: EventsResponse = block_on(async {
        let account = create_account(&test).await;
        let latest: EventsResponse =
            test.get(&account.owner, &events_path(0)).await.json();
        test.get(&account.owner, &events_path(latest.latest_sequence))
            .await
            .json()
    });

    assert_eq!(events.notifications.len(), 0);
    assert_eq!(events.latest_sequence, 1);
}

#[test]
fn a_waiting_poll_wakes_up_on_a_change() {
    let test =
        TestServer::start_with_long_poll_timeout(PATIENT_LONG_POLL_TIMEOUT);
    let events: EventsResponse = block_on(async {
        let account = create_account(&test).await;
        let waiting_path = events_path(1);
        let waiting_poll = test.get(&account.owner, &waiting_path);
        let later_change = async {
            tokio::time::sleep(DELAY_BEFORE_CHANGE).await;
            create_project(&test, &account).await
        };
        let (response, _project) = tokio::join!(waiting_poll, later_change);
        response.json()
    });

    assert_eq!(events.notifications.len(), 1);
    assert_eq!(events.notifications[0].topic, ChangeTopic::Projects);
}
