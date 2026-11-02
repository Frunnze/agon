use chrono::{DateTime, TimeDelta, Utc};
use orchestration_core::device::{Device, DeviceRole, HardwareKeyKind};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::peer_address::{
    ENDPOINT_PUBLIC_KEY_LENGTH, PeerAddress,
};
use orchestration_core::server_group::{
    AuditSigners, ServerGroup, ServerMember, ServerMembership, ServerStanding,
    ServerTerm,
};
use orchestration_node::views::{ThisDeviceStanding, describe_app_servers};
use proptest::prelude::*;

const MOST_MEMBERS: usize = 4;

fn member_hosted_by(position: usize) -> ServerMember {
    let endpoint_public_key = [0; ENDPOINT_PUBLIC_KEY_LENGTH];
    let offset = i64::try_from(position).unwrap_or_default();
    ServerMember {
        membership: ServerMembership {
            device_id: DeviceId(format!("device-{position}")),
            server_id: DeviceId(format!("server-{position}")),
            server_signing_public_key: Vec::new(),
            endpoint_public_key,
            joined_at: DateTime::<Utc>::UNIX_EPOCH
                + TimeDelta::seconds(offset),
            signature: Vec::new(),
        },
        address: PeerAddress {
            endpoint_public_key,
            direct_addresses: Vec::new(),
            relay_url: None,
        },
    }
}

fn group_of(member_count: usize, active_position: usize) -> ServerGroup {
    let members: Vec<ServerMember> =
        (0..member_count).map(member_hosted_by).collect();
    let active = &members[active_position % member_count].membership;
    ServerGroup {
        term: Some(ServerTerm {
            number: 1,
            server_id: active.server_id.clone(),
            claimed_by: active.device_id.clone(),
            signature: Vec::new(),
        }),
        members,
        audit_signers: AuditSigners::new(),
    }
}

fn device_with(device_id: DeviceId, role: DeviceRole) -> Device {
    Device {
        id: device_id,
        name: "air-laptop".to_owned(),
        role,
        key_kind: HardwareKeyKind::Software,
        signing_public_key: Vec::new(),
        sealing_public_key: Vec::new(),
        workspaces: Vec::new(),
        paired_at: DateTime::<Utc>::UNIX_EPOCH,
        approved_by: None,
        last_seen: DateTime::<Utc>::UNIX_EPOCH,
        revoked: false,
        peer_address: None,
    }
}

fn role_strategy() -> impl Strategy<Value = DeviceRole> {
    prop_oneof![
        Just(DeviceRole::Client),
        Just(DeviceRole::Runner),
        Just(DeviceRole::ClientAndRunner),
    ]
}

proptest! {
    #[test]
    fn test_describe_app_servers_property_lists_the_active_server_first(
        member_count in 1..=MOST_MEMBERS,
        active_position in 0..MOST_MEMBERS,
        own_position in 0..=MOST_MEMBERS,
        role in role_strategy(),
    ) {
        let group = group_of(member_count, active_position);
        let own_id = DeviceId(format!("device-{own_position}"));
        let device = device_with(own_id.clone(), role);
        let active_device =
            DeviceId(format!("device-{}", active_position % member_count));

        let view = describe_app_servers(Some(&group), Some(&device));

        prop_assert_eq!(view.servers.len(), member_count);
        prop_assert_eq!(&view.servers[0].device_id, &active_device);
        prop_assert_eq!(view.servers[0].standing, ServerStanding::Active);
        for server in &view.servers[1..] {
            prop_assert_eq!(server.standing, ServerStanding::Backup);
        }
        let expected_standing = if own_id == active_device {
            ThisDeviceStanding::Active
        } else if own_position < member_count {
            ThisDeviceStanding::Backup
        } else {
            ThisDeviceStanding::None
        };
        prop_assert_eq!(view.this_device, expected_standing);
        prop_assert_eq!(view.can_keep_backup, role != DeviceRole::Runner);
    }

    #[test]
    fn test_describe_app_servers_property_no_group_keeps_no_backup(
        role in role_strategy(),
    ) {
        let device = device_with(DeviceId("device-0".to_owned()), role);

        let without_group = describe_app_servers(None, Some(&device));
        let unfounded = describe_app_servers(
            Some(&ServerGroup::default()),
            Some(&device),
        );
        let without_account = describe_app_servers(None, None);

        for view in [without_group, unfounded, without_account] {
            prop_assert!(view.servers.is_empty());
            prop_assert_eq!(view.this_device, ThisDeviceStanding::None);
            prop_assert!(!view.can_keep_backup);
        }
    }
}

#[test]
fn test_describe_app_servers_property_writes_the_status_field_shape() {
    let group = group_of(2, 0);
    let device =
        device_with(DeviceId("device-1".to_owned()), DeviceRole::Client);

    let view = describe_app_servers(Some(&group), Some(&device));
    let encoded = serde_json::to_value(&view).unwrap_or_default();

    assert_eq!(
        encoded,
        serde_json::json!({
            "servers": [
                {"device_id": "device-0", "standing": "active"},
                {"device_id": "device-1", "standing": "backup"},
            ],
            "this_device": "backup",
            "can_keep_backup": true,
        })
    );
}
