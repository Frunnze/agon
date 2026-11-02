use orchestration_node::server_address::ServerAddress;
use orchestration_node::server_order::{
    OwnServerRoute, order_server_addresses,
};
use proptest::prelude::*;

use crate::support::address_strategies::server_address_strategy;
use crate::support::group_strategies::{group_strategy, hex_key};

const LOOPBACK_ADDRESS: &str = "http://127.0.0.1:8731";

fn identity_of(address: &ServerAddress) -> String {
    match address {
        ServerAddress::Web(web_address) => web_address.clone(),
        ServerAddress::Peer(peer_address) => hex_key(peer_address),
    }
}

proptest! {
    #[test]
    fn test_order_server_addresses_property_lists_each_server_once(
        primary in server_address_strategy(),
        group in proptest::option::of(group_strategy()),
    ) {
        let ordered = order_server_addresses(&primary, group.as_ref(), None);
        let identities: Vec<String> =
            ordered.iter().map(identity_of).collect();
        let mut unique = identities.clone();
        unique.sort();
        unique.dedup();

        prop_assert_eq!(unique.len(), identities.len());
        prop_assert!(identities.contains(&identity_of(&primary)));
        let member_count =
            group.as_ref().map_or(0, |group| group.members.len());
        prop_assert!(ordered.len() <= member_count + 1);
    }

    #[test]
    fn test_order_server_addresses_property_puts_the_active_server_first(
        primary in server_address_strategy(),
        group in group_strategy(),
    ) {
        let ordered = order_server_addresses(&primary, Some(&group), None);
        let active_id = group.active_server_id().cloned();
        let active = group
            .members
            .iter()
            .find(|member| {
                Some(&member.membership.server_id) == active_id.as_ref()
            })
            .ok_or_else(|| TestCaseError::fail("the group has an active"))?;

        prop_assert_eq!(
            ordered.first(),
            Some(&ServerAddress::Peer(active.address.clone()))
        );
    }

    #[test]
    fn test_order_server_addresses_property_reaches_its_own_server_locally(
        group in group_strategy(),
        own_index in any::<prop::sample::Index>(),
    ) {
        let own_member = own_index.get(&group.members).clone();
        let local_address = ServerAddress::Web(LOOPBACK_ADDRESS.to_owned());
        let own_server = OwnServerRoute {
            endpoint_public_key: own_member.address.endpoint_public_key,
            local_address: local_address.clone(),
        };

        let ordered = order_server_addresses(
            &local_address,
            Some(&group),
            Some(&own_server),
        );

        prop_assert!(ordered.contains(&local_address));
        let own_peer_address = ServerAddress::Peer(own_member.address);
        prop_assert!(!ordered.contains(&own_peer_address));
        prop_assert_eq!(ordered.len(), group.members.len());
    }
}
