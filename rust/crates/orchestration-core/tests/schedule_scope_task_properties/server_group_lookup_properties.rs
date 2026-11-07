use std::net::SocketAddr;

use orchestration_core::peer_address::ENDPOINT_PUBLIC_KEY_LENGTH;
use orchestration_core::server_group::{ServerGroup, ServerTerm};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::server_group_support::{
    MOST_JOIN_SECOND, MOST_TERM_NUMBER, SERVER_NAMES, STRANGER_NAME,
    any_group, device_of, group_of, joined_at, kept_group, member_for, server,
    term,
};

const MOST_ADDRESSES: usize = 3;
const MOST_KEY_BYTES: usize = 8;

fn any_term() -> impl Strategy<Value = ServerTerm> {
    (
        0..MOST_TERM_NUMBER,
        prop::sample::select(SERVER_NAMES.to_vec()),
    )
        .prop_map(|(number, name)| term(number, name))
}

proptest! {
    #[test]
    fn test_has_signed_address_property_ignores_where_the_server_listens(
        signed_key in any::<[u8; ENDPOINT_PUBLIC_KEY_LENGTH]>(),
        address_key in any::<[u8; ENDPOINT_PUBLIC_KEY_LENGTH]>(),
        direct_addresses in vec(any::<SocketAddr>(), 0..MOST_ADDRESSES),
        relay_url in proptest::option::of("[a-z:/.]{0,12}"),
    ) {
        let mut plain = member_for("a", 0);
        plain.membership.endpoint_public_key = signed_key;
        plain.address.endpoint_public_key = address_key;
        let mut listening = plain.clone();
        listening.address.direct_addresses = direct_addresses;
        listening.address.relay_url = relay_url;

        prop_assert_eq!(
            listening.has_signed_address(),
            plain.has_signed_address()
        );
    }

    #[test]
    fn test_has_signed_address_property_ignores_the_other_membership_fields(
        name in prop::sample::select(SERVER_NAMES.to_vec()),
        joined_second in any::<i32>(),
        signature in vec(any::<u8>(), 0..MOST_KEY_BYTES),
        signing_key in vec(any::<u8>(), 0..MOST_KEY_BYTES),
    ) {
        let mut member = member_for("a", 0);
        member.membership.server_id = server(name);
        member.membership.device_id = device_of(name);
        member.membership.joined_at = joined_at(i64::from(joined_second));
        member.membership.signature = signature;
        member.membership.server_signing_public_key = signing_key;

        prop_assert!(member.has_signed_address());
    }

    #[test]
    fn test_outranks_property_is_transitive(
        first in any_term(),
        second in any_term(),
        third in any_term(),
    ) {
        if first.outranks(&second) && second.outranks(&third) {
            prop_assert!(first.outranks(&third));
        }
    }

    #[test]
    fn test_outranks_property_ignores_the_claimer_and_signature(
        first in any_term(),
        second in any_term(),
        claimer in prop::sample::select(SERVER_NAMES.to_vec()),
        signature in vec(any::<u8>(), 0..MOST_KEY_BYTES),
    ) {
        let reclaimed = ServerTerm {
            claimed_by: device_of(claimer),
            signature,
            ..first.clone()
        };

        prop_assert_eq!(reclaimed.outranks(&second), first.outranks(&second));
        prop_assert_eq!(second.outranks(&reclaimed), second.outranks(&first));
        prop_assert!(!reclaimed.outranks(&first));
    }

    #[test]
    fn test_active_server_id_property_is_none_without_a_term(
        group in any_group(),
    ) {
        let without_term = ServerGroup { term: None, ..group };

        prop_assert_eq!(without_term.active_server_id(), None);
    }

    #[test]
    fn test_active_server_id_property_ignores_the_member_list(
        group in any_group(),
    ) {
        let without_members = group_of(group.term.clone(), Vec::new());

        prop_assert_eq!(
            group.active_server_id(),
            without_members.active_server_id()
        );
    }

    #[test]
    fn test_has_backups_property_agrees_with_the_backup_list(
        group in kept_group(),
    ) {
        let backups = group.backups_in_order();

        prop_assert_eq!(group.has_backups(), !backups.is_empty());
    }

    #[test]
    fn test_has_backups_property_a_lone_active_server_has_none(
        name in prop::sample::select(SERVER_NAMES.to_vec()),
        number in 1..MOST_TERM_NUMBER,
        joined_second in 0..MOST_JOIN_SECOND,
    ) {
        let members = vec![member_for(name, joined_second)];
        let group = group_of(Some(term(number, name)), members);

        prop_assert!(!group.has_backups());
    }

    #[test]
    fn test_has_backups_property_a_joining_server_becomes_a_backup(
        group in kept_group(),
        joined_second in 0..MOST_JOIN_SECOND,
    ) {
        let mut joined = group.clone();
        joined.members.push(member_for(STRANGER_NAME, joined_second));

        prop_assert!(joined.has_backups());
    }

    #[test]
    fn test_find_member_property_finds_every_member_by_its_server(
        group in kept_group(),
    ) {
        for member in &group.members {
            let found = group.find_member(&member.membership.server_id);
            prop_assert_eq!(found, Some(member));
        }
    }

    #[test]
    fn test_find_member_property_found_members_carry_that_server_id(
        group in any_group(),
        name in prop::sample::select(SERVER_NAMES.to_vec()),
    ) {
        let wanted = server(name);
        let is_listed = group
            .members
            .iter()
            .any(|member| member.membership.server_id == wanted);

        let found = group.find_member(&wanted);

        prop_assert_eq!(found.is_some(), is_listed);
        if let Some(member) = found {
            prop_assert_eq!(&member.membership.server_id, &wanted);
        }
    }

    #[test]
    fn test_find_member_property_never_matches_a_device_id(
        group in kept_group(),
    ) {
        for member in &group.members {
            let by_device = group.find_member(&member.membership.device_id);
            prop_assert_eq!(by_device, None);
        }
    }

    #[test]
    fn test_find_member_of_device_property_finds_every_hosting_device(
        group in kept_group(),
    ) {
        for member in &group.members {
            let device_id = &member.membership.device_id;
            let found = group.find_member_of_device(device_id);
            prop_assert_eq!(found, Some(member));
        }
    }

    #[test]
    fn test_find_member_of_device_property_found_member_runs_on_it(
        group in any_group(),
        name in prop::sample::select(SERVER_NAMES.to_vec()),
    ) {
        let wanted = device_of(name);
        let is_listed = group
            .members
            .iter()
            .any(|member| member.membership.device_id == wanted);

        let found = group.find_member_of_device(&wanted);

        prop_assert_eq!(found.is_some(), is_listed);
        if let Some(member) = found {
            prop_assert_eq!(&member.membership.device_id, &wanted);
        }
    }

    #[test]
    fn test_find_member_of_device_property_never_matches_a_server_id(
        group in kept_group(),
    ) {
        for member in &group.members {
            let server_id = &member.membership.server_id;
            prop_assert_eq!(group.find_member_of_device(server_id), None);
        }
    }
}
