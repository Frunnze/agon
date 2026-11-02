use orchestration_core::identifiers::DeviceId;
use orchestration_core::peer_address::ENDPOINT_PUBLIC_KEY_LENGTH;
use orchestration_core::server_group::ServerGroup;
use orchestration_node::node::Node;
use orchestration_node::node_configuration::{
    DEFAULT_APP_SERVER_PORT, DEFAULT_TAKEOVER_SECONDS, IdentityStoreChoice,
    NodeConfiguration, PeerRelayChoice,
};
use orchestration_node::node_error::NodeError;
use orchestration_node::server_group_check::check_server_group;
use proptest::collection::vec;
use proptest::prelude::*;
use tempfile::TempDir;

use crate::support::group_strategies::group_strategy;
use crate::support::test_device::fail;

const STRANGER_SERVER_ID: &str = "not-a-member";
const MOST_OFFERS: usize = 6;

fn has_malformed_group_problem(outcome: &Result<(), NodeError>) -> bool {
    matches!(outcome, Err(NodeError::MalformedServerGroup(_)))
}

fn drop_term(mut group: ServerGroup) -> ServerGroup {
    group.term = None;
    group
}

fn open_node(data_directory: &TempDir) -> Result<Node, NodeError> {
    let configuration = NodeConfiguration {
        data_directory: data_directory.path().to_path_buf(),
        identity_store: IdentityStoreChoice::File,
        runner: None,
        peer_relay: PeerRelayChoice::Disabled,
        app_server_port: DEFAULT_APP_SERVER_PORT,
        server_takeover_seconds: DEFAULT_TAKEOVER_SECONDS,
    };
    Node::open(&configuration)
}

fn offered_group_strategy() -> impl Strategy<Value = ServerGroup> {
    prop_oneof![
        group_strategy(),
        group_strategy().prop_map(drop_term),
        Just(ServerGroup::default()),
    ]
}

proptest! {
    #[test]
    fn test_check_server_group_property_accepts_every_group_a_server_keeps(
        group in proptest::option::of(group_strategy()),
    ) {
        let kept_group = group.unwrap_or_default();

        prop_assert!(check_server_group(&kept_group).is_ok());
    }

    #[test]
    fn test_check_server_group_property_refuses_members_without_a_term(
        group in group_strategy(),
    ) {
        let without_term = drop_term(group);

        let outcome = check_server_group(&without_term);

        prop_assert!(has_malformed_group_problem(&outcome));
    }

    #[test]
    fn test_check_server_group_property_refuses_a_term_naming_no_member(
        mut group in group_strategy(),
    ) {
        if let Some(term) = group.term.as_mut() {
            term.server_id = DeviceId(STRANGER_SERVER_ID.to_owned());
        }

        let outcome = check_server_group(&group);

        prop_assert!(has_malformed_group_problem(&outcome));
    }

    #[test]
    fn test_check_server_group_property_refuses_an_address_off_its_key(
        mut group in group_strategy(),
        member_index in any::<prop::sample::Index>(),
        other_key in any::<[u8; ENDPOINT_PUBLIC_KEY_LENGTH]>(),
    ) {
        let chosen = member_index.index(group.members.len());
        let member = &mut group.members[chosen];
        prop_assume!(other_key != member.membership.endpoint_public_key);
        member.address.endpoint_public_key = other_key;

        let outcome = check_server_group(&group);

        prop_assert!(has_malformed_group_problem(&outcome));
    }

    #[test]
    fn test_remember_server_group_property_keeps_the_last_well_formed_group(
        offered_groups in vec(offered_group_strategy(), 1..MOST_OFFERS),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        let mut last_well_formed = None;

        for offered in offered_groups {
            let is_well_formed = check_server_group(&offered).is_ok();
            let remembered = node.remember_server_group(&offered);
            prop_assert_eq!(remembered.is_ok(), is_well_formed);
            if is_well_formed {
                last_well_formed = Some(offered);
            }
        }

        let stored = node.device_files().load_server_group().map_err(fail)?;
        prop_assert_eq!(stored, last_well_formed);
    }
}
