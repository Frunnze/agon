use chrono::{DateTime, Utc};
use orchestration_core::device::RunnerLink;
use orchestration_core::run_links::{is_connected, record_link_change};
use proptest::prelude::*;

use crate::entity_strategies::ordinary_timestamp;
use crate::run_fixtures::run_with_steps;

fn any_link() -> impl Strategy<Value = RunnerLink> {
    prop_oneof![
        Just(RunnerLink::Direct),
        Just(RunnerLink::Relay),
        Just(RunnerLink::LocalNetwork),
        Just(RunnerLink::Unreachable),
    ]
}

fn any_lost_time() -> impl Strategy<Value = Option<DateTime<Utc>>> {
    proptest::option::of(ordinary_timestamp())
}

proptest! {
    #[test]
    fn test_record_link_change_property_marks_the_moment_a_link_drops(
        previous_link in any_link(),
        previous_lost_at in any_lost_time(),
        next_link in any_link(),
        at in ordinary_timestamp(),
    ) {
        let run = run_with_steps(Vec::new());
        let before = orchestration_core::run::Run {
            link: previous_link,
            link_lost_at: previous_lost_at,
            ..run
        };

        let after = record_link_change(&before, next_link, at);

        prop_assert_eq!(after.link, next_link);
        let expected_lost_at = if is_connected(next_link) {
            None
        } else if is_connected(previous_link) {
            Some(at)
        } else {
            previous_lost_at
        };
        prop_assert_eq!(after.link_lost_at, expected_lost_at);
        prop_assert_eq!(&after.steps, &before.steps);
        prop_assert_eq!(after.status, before.status);
    }

    #[test]
    fn test_record_link_change_property_repeating_a_link_changes_nothing(
        link in any_link(),
        first_at in ordinary_timestamp(),
        second_at in ordinary_timestamp(),
    ) {
        let run = run_with_steps(Vec::new());
        let connected = record_link_change(&run, RunnerLink::Direct, first_at);
        let once = record_link_change(&connected, link, first_at);

        let twice = record_link_change(&once, link, second_at);

        prop_assert_eq!(twice, once);
    }
}
