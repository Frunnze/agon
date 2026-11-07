use chrono::{DateTime, Utc};
use orchestration_core::device::RunnerLink;
use orchestration_core::run::Run;
use orchestration_core::run_links::{is_connected, record_link_change};
use proptest::collection::vec;
use proptest::option;
use proptest::prelude::*;
use serde_json::json;

use crate::entity_strategies::ordinary_timestamp;
use crate::run_fixtures::run_with_steps;
use crate::workflow_strategies::run_steps;

const MAXIMUM_LINK_CHANGES: usize = 8;
const UNREACHABLE_WIRE_NAME: &str = "unreachable";

fn connected_link() -> impl Strategy<Value = RunnerLink> {
    prop_oneof![
        Just(RunnerLink::Direct),
        Just(RunnerLink::Relay),
        Just(RunnerLink::LocalNetwork),
    ]
}

fn runner_link() -> impl Strategy<Value = RunnerLink> {
    prop_oneof![connected_link(), Just(RunnerLink::Unreachable)]
}

fn linked_run() -> impl Strategy<Value = Run> {
    (
        run_steps(),
        runner_link(),
        option::of(ordinary_timestamp()),
        any::<u32>(),
    )
        .prop_map(|(steps, link, link_lost_at, number)| Run {
            link,
            link_lost_at,
            number,
            ..run_with_steps(steps)
        })
}

fn link_changes() -> impl Strategy<Value = Vec<(RunnerLink, DateTime<Utc>)>> {
    vec(
        (runner_link(), ordinary_timestamp()),
        0..MAXIMUM_LINK_CHANGES,
    )
}

fn expected_lost_moment(
    changes: &[(RunnerLink, DateTime<Utc>)],
) -> Option<DateTime<Utc>> {
    let last_connected_position =
        changes.iter().rposition(|(link, _)| is_connected(*link))?;
    let first_drop_after = changes[last_connected_position + 1..].first()?;
    Some(first_drop_after.1)
}

proptest! {
    #[test]
    fn test_record_link_change_property_keeps_every_other_field(
        run in linked_run(),
        link in runner_link(),
        at in ordinary_timestamp(),
    ) {
        let changed = record_link_change(&run, link, at);

        let restored = Run {
            link: run.link,
            link_lost_at: run.link_lost_at,
            ..changed.clone()
        };
        prop_assert_eq!(changed.link, link);
        prop_assert_eq!(restored, run);
    }

    #[test]
    fn test_record_link_change_property_lost_moment_is_the_first_drop(
        changes in link_changes(),
    ) {
        let created_run = Run {
            link: RunnerLink::Unreachable,
            link_lost_at: None,
            ..run_with_steps(Vec::new())
        };

        let mut changed_run = created_run;
        for (link, at) in &changes {
            changed_run = record_link_change(&changed_run, *link, *at);
        }

        let final_link = changes
            .last()
            .map_or(RunnerLink::Unreachable, |change| change.0);
        let expected_lost_at = expected_lost_moment(&changes);
        prop_assert_eq!(changed_run.link, final_link);
        prop_assert_eq!(changed_run.link_lost_at, expected_lost_at);
    }

    #[test]
    fn test_is_connected_property_only_unreachable_is_disconnected(
        link in runner_link(),
    ) {
        let wire_name = serde_json::to_value(link).ok();

        let is_unreachable = wire_name == Some(json!(UNREACHABLE_WIRE_NAME));
        prop_assert_eq!(is_connected(link), !is_unreachable);
    }

    #[test]
    fn test_is_connected_property_connected_links_keep_no_lost_moment(
        run in linked_run(),
        link in connected_link(),
        at in ordinary_timestamp(),
    ) {
        let changed = record_link_change(&run, link, at);

        prop_assert_eq!(changed.link_lost_at, None);
    }

    #[test]
    fn test_is_connected_property_dropping_a_connection_marks_the_moment(
        run in linked_run(),
        previous_link in connected_link(),
        link in runner_link(),
        at in ordinary_timestamp(),
    ) {
        let connected_run = Run {
            link: previous_link,
            link_lost_at: None,
            ..run
        };

        let changed = record_link_change(&connected_run, link, at);

        let expected = (!is_connected(link)).then_some(at);
        prop_assert_eq!(changed.link_lost_at, expected);
    }
}
