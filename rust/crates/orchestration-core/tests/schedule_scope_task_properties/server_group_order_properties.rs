use std::collections::BTreeSet;

use orchestration_core::identifiers::DeviceId;
use orchestration_core::server_group::{ServerGroup, ServerMember};
use proptest::prelude::*;

use crate::server_group_support::{
    SERVER_NAMES, STRANGER_NAME, any_group, group_of, join_key, kept_group,
    member_for, reversed_members, server, server_ids,
};

const SHARED_JOIN_SECOND: i64 = 0;
const SMALLEST_SHARED_GROUP: usize = 2;

fn sorted_ids(members: &[ServerMember]) -> Vec<DeviceId> {
    let mut ids: Vec<DeviceId> = Vec::new();
    for member in members {
        ids.push(member.membership.server_id.clone());
    }
    ids.sort();
    ids
}

fn active_id(group: &ServerGroup) -> Result<DeviceId, TestCaseError> {
    group
        .active_server_id()
        .cloned()
        .ok_or_else(|| TestCaseError::fail("a kept group has a term"))
}

proptest! {
    #[test]
    fn test_backups_in_order_property_ignores_the_listing_order(
        group in any_group(),
    ) {
        let reversed = reversed_members(&group);

        prop_assert_eq!(
            server_ids(&group.backups_in_order()),
            server_ids(&reversed.backups_in_order())
        );
    }

    #[test]
    fn test_backups_in_order_property_without_a_term_lists_every_member(
        group in any_group(),
    ) {
        let without_term = ServerGroup { term: None, ..group };

        let backups = without_term.backups_in_order();

        let mut listed_ids = server_ids(&backups);
        listed_ids.sort();
        prop_assert_eq!(listed_ids, sorted_ids(&without_term.members));
    }

    #[test]
    fn test_members_active_first_property_lists_every_member_once(
        group in any_group(),
    ) {
        let ordered = group.members_active_first();

        let mut ordered_ids = server_ids(&ordered);
        ordered_ids.sort();
        prop_assert_eq!(ordered_ids, sorted_ids(&group.members));
    }

    #[test]
    fn test_members_active_first_property_puts_backups_behind_the_active(
        group in kept_group(),
    ) {
        let ordered = group.members_active_first();
        let active = active_id(&group)?;

        let first_id =
            ordered.first().map(|member| &member.membership.server_id);
        prop_assert_eq!(first_id, Some(&active));
        prop_assert_eq!(
            server_ids(&ordered[1..]),
            server_ids(&group.backups_in_order())
        );
    }

    #[test]
    fn test_members_active_first_property_ignores_the_listing_order(
        group in any_group(),
    ) {
        let reversed = reversed_members(&group);

        prop_assert_eq!(
            server_ids(&group.members_active_first()),
            server_ids(&reversed.members_active_first())
        );
    }

    #[test]
    fn test_takeover_position_property_gives_each_backup_its_own_turn(
        group in kept_group(),
    ) {
        let active = active_id(&group)?;
        let mut positions: BTreeSet<usize> = BTreeSet::new();

        for member in &group.members {
            let server_id = &member.membership.server_id;
            if let Some(position) = group.takeover_position(server_id, &active)
            {
                positions.insert(position);
            }
        }

        let expected: BTreeSet<usize> = (1..group.members.len()).collect();
        prop_assert_eq!(positions, expected);
    }

    #[test]
    fn test_takeover_position_property_earlier_joiners_go_first(
        group in kept_group(),
        stand_in_index in any::<prop::sample::Index>(),
    ) {
        let stand_in = stand_in_index.get(&group.members);
        let stand_in_id = stand_in.membership.server_id.clone();

        for first in &group.members {
            for second in &group.members {
                let first_id = &first.membership.server_id;
                let second_id = &second.membership.server_id;
                let first_turn =
                    group.takeover_position(first_id, &stand_in_id);
                let second_turn =
                    group.takeover_position(second_id, &stand_in_id);
                let both_wait = first_turn.is_some() && second_turn.is_some();
                if both_wait && join_key(first) < join_key(second) {
                    prop_assert!(first_turn < second_turn);
                }
            }
        }
        prop_assert_eq!(
            group.takeover_position(&stand_in_id, &stand_in_id),
            None
        );
    }

    #[test]
    fn test_backups_behind_property_leaves_out_only_the_active_server(
        group in kept_group(),
    ) {
        let active = active_id(&group)?;

        let backups = group.backups_in_order();

        prop_assert_eq!(backups.len() + 1, group.members.len());
        let backup_ids = server_ids(&backups);
        prop_assert!(!backup_ids.contains(&active));
    }

    #[test]
    fn test_backups_behind_property_sorts_by_join_time_then_server(
        group in any_group(),
    ) {
        let backups = group.backups_in_order();

        for pair in backups.windows(2) {
            prop_assert!(join_key(pair[0]) < join_key(pair[1]));
        }
    }

    #[test]
    fn test_backups_behind_property_same_moment_joiners_follow_server_ids(
        names in prop::sample::subsequence(
            SERVER_NAMES.to_vec(),
            SMALLEST_SHARED_GROUP..=SERVER_NAMES.len(),
        )
        .prop_shuffle(),
    ) {
        let mut members: Vec<ServerMember> = Vec::new();
        for name in &names {
            members.push(member_for(name, SHARED_JOIN_SECOND));
        }
        let group = group_of(None, members);

        let stranger = server(STRANGER_NAME);
        let first_turn = group.takeover_position(&server(names[0]), &stranger);

        let mut expected_ids: Vec<DeviceId> = Vec::new();
        for name in &names {
            expected_ids.push(server(name));
        }
        expected_ids.sort();
        let backup_ids = server_ids(&group.backups_in_order());
        prop_assert_eq!(backup_ids, expected_ids.clone());
        let expected_turn = expected_ids
            .iter()
            .position(|server_id| *server_id == server(names[0]))
            .map(|index| index + 1);
        prop_assert_eq!(first_turn, expected_turn);
    }
}
