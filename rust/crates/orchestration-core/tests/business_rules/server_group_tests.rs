use chrono::{DateTime, TimeDelta, Utc};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::peer_address::{
    ENDPOINT_PUBLIC_KEY_LENGTH, PeerAddress,
};
use orchestration_core::server_group::{
    AuditSigners, ServerGroup, ServerMember, ServerMembership, ServerTerm,
};
use proptest::collection::vec;
use proptest::prelude::*;

const MOST_MEMBERS: usize = 6;
const MOST_TERM_NUMBER: u64 = 8;
const LATEST_JOIN_SECOND: i64 = 1_000;
const SERVER_ID_PATTERN: &str = "[a-f]{1,3}";

fn term_strategy() -> impl Strategy<Value = ServerTerm> {
    (0..MOST_TERM_NUMBER, SERVER_ID_PATTERN).prop_map(|(number, server)| {
        ServerTerm {
            number,
            server_id: DeviceId(server),
            claimed_by: DeviceId("device".to_owned()),
            signature: Vec::new(),
        }
    })
}

fn member_for(server_id: String, joined_second: i64) -> ServerMember {
    let joined_at =
        DateTime::<Utc>::UNIX_EPOCH + TimeDelta::seconds(joined_second);
    let endpoint_public_key = [0; ENDPOINT_PUBLIC_KEY_LENGTH];
    ServerMember {
        membership: ServerMembership {
            device_id: DeviceId(format!("device-{server_id}")),
            server_id: DeviceId(server_id),
            server_signing_public_key: Vec::new(),
            endpoint_public_key,
            joined_at,
            signature: Vec::new(),
        },
        address: PeerAddress {
            endpoint_public_key,
            direct_addresses: Vec::new(),
            relay_url: None,
        },
    }
}

fn group_strategy() -> impl Strategy<Value = ServerGroup> {
    let members =
        vec((SERVER_ID_PATTERN, 0..LATEST_JOIN_SECOND), 1..MOST_MEMBERS)
            .prop_map(|chosen| {
                let mut members: Vec<ServerMember> = Vec::new();
                for (server_id, joined_second) in chosen {
                    let is_new = members.iter().all(|member| {
                        member.membership.server_id.0 != server_id
                    });
                    if is_new {
                        members.push(member_for(server_id, joined_second));
                    }
                }
                members
            });
    (members, any::<prop::sample::Index>(), 1..MOST_TERM_NUMBER).prop_map(
        |(members, active_index, number)| {
            let active = active_index.get(&members);
            let term = ServerTerm {
                number,
                server_id: active.membership.server_id.clone(),
                claimed_by: active.membership.device_id.clone(),
                signature: Vec::new(),
            };
            ServerGroup {
                term: Some(term),
                members,
                audit_signers: AuditSigners::new(),
            }
        },
    )
}

fn order_key(member: &ServerMember) -> (DateTime<Utc>, DeviceId) {
    (
        member.membership.joined_at,
        member.membership.server_id.clone(),
    )
}

proptest! {
    #[test]
    fn test_outranks_property_orders_by_number_then_server(
        first in term_strategy(),
        second in term_strategy(),
    ) {
        let first_key = (first.number, first.server_id.clone());
        let second_key = (second.number, second.server_id.clone());

        prop_assert_eq!(first.outranks(&second), first_key > second_key);
        prop_assert!(!(first.outranks(&second) && second.outranks(&first)));
        prop_assert!(!first.outranks(&first));
        if first.number > second.number {
            prop_assert!(first.outranks(&second));
        }
    }

    #[test]
    fn test_backups_in_order_property_follows_join_order_without_active(
        group in group_strategy(),
    ) {
        let backups = group.backups_in_order();
        let active = group.active_server_id().cloned();

        prop_assert_eq!(backups.len() + 1, group.members.len());
        for backup in &backups {
            let backup_id = &backup.membership.server_id;
            prop_assert_ne!(Some(backup_id), active.as_ref());
        }
        for pair in backups.windows(2) {
            prop_assert!(order_key(pair[0]) <= order_key(pair[1]));
        }
    }

    #[test]
    fn test_takeover_position_property_counts_backups_from_one(
        group in group_strategy(),
    ) {
        let backups = group.backups_in_order();
        let active = group
            .active_server_id()
            .cloned()
            .ok_or_else(|| TestCaseError::fail("the group has a term"))?;

        for (index, backup) in backups.iter().enumerate() {
            let position =
                group.takeover_position(&backup.membership.server_id, &active);
            prop_assert_eq!(position, Some(index + 1));
        }
        prop_assert_eq!(group.takeover_position(&active, &active), None);
        let stranger = DeviceId("not-a-member".to_owned());
        prop_assert_eq!(group.takeover_position(&stranger, &active), None);
    }

    #[test]
    fn test_active_server_id_property_names_the_term_server(
        group in group_strategy(),
    ) {
        let term_server = group.term.as_ref().map(|term| &term.server_id);

        prop_assert_eq!(group.active_server_id(), term_server);
        prop_assert_eq!(group.has_backups(), group.members.len() > 1);
        let ordered = group.members_active_first();
        prop_assert_eq!(ordered.len(), group.members.len());
        prop_assert_eq!(
            ordered.first().map(|member| &member.membership.server_id),
            term_server
        );
        for member in &group.members {
            let found = group.find_member(&member.membership.server_id);
            prop_assert_eq!(found, Some(member));
            let hosted =
                group.find_member_of_device(&member.membership.device_id);
            prop_assert_eq!(hosted, Some(member));
        }
    }

    #[test]
    fn test_has_signed_address_property_matches_only_the_signed_key(
        server_id in SERVER_ID_PATTERN,
        address_key in any::<[u8; ENDPOINT_PUBLIC_KEY_LENGTH]>(),
    ) {
        let mut member = member_for(server_id, 0);
        let signed_key = member.membership.endpoint_public_key;
        member.address.endpoint_public_key = address_key;

        let is_signed_key = address_key == signed_key;
        prop_assert_eq!(member.has_signed_address(), is_signed_key);
        member.address.endpoint_public_key = signed_key;
        prop_assert!(member.has_signed_address());
    }

    #[test]
    fn test_server_group_property_survives_arbitrary_json(
        text in ".{0,64}",
    ) {
        let parsed = serde_json::from_str::<ServerGroup>(&text);

        if let Ok(group) = parsed {
            let written = serde_json::to_string(&group)?;
            let read_back = serde_json::from_str::<ServerGroup>(&written)?;
            prop_assert_eq!(read_back, group);
        }
    }
}

#[test]
fn test_server_group_property_empty_group_has_no_active_server() {
    let group = ServerGroup::default();

    assert_eq!(group.active_server_id(), None);
    assert!(!group.has_backups());
    assert_eq!(group.backups_in_order().len(), 0);
}
