use std::net::SocketAddr;

use chrono::{DateTime, Utc};
use orchestration_api::accounts::{
    AccountView, DeviceRegistration, JoiningDevice, SealedWorkspaceKey,
};
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::{
    Device, DeviceKind, DeviceRole, HardwareKeyKind,
};
use orchestration_core::identifiers::{DeviceId, WorkspaceId};
use orchestration_core::peer_address::{PeerAddress, SignedPeerAddress};
use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::workspace::Workspace;
use proptest::collection::vec;
use proptest::option;
use proptest::prelude::*;
use uuid::Uuid;

const MAXIMUM_BYTES: usize = 8;
const MAXIMUM_ITEMS: usize = 3;
const LATEST_TIMESTAMP_SECONDS: i64 = 4_102_444_800;
const NANOSECONDS_PER_SECOND: u32 = 1_000_000_000;

pub fn bytes() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), 0..MAXIMUM_BYTES)
}

pub fn text() -> impl Strategy<Value = String> {
    "\\PC{0,12}"
}

pub fn timestamp() -> impl Strategy<Value = DateTime<Utc>> {
    (0..LATEST_TIMESTAMP_SECONDS, 0..NANOSECONDS_PER_SECOND).prop_filter_map(
        "timestamp in range",
        |(seconds, nanoseconds)| {
            DateTime::from_timestamp(seconds, nanoseconds)
        },
    )
}

pub fn workspace_identifier() -> impl Strategy<Value = WorkspaceId> {
    any::<u128>().prop_map(|number| WorkspaceId(Uuid::from_u128(number)))
}

pub fn device_identifier() -> impl Strategy<Value = DeviceId> {
    "[0-9a-f]{1,32}".prop_map(DeviceId)
}

fn device_role() -> impl Strategy<Value = DeviceRole> {
    prop_oneof![
        Just(DeviceRole::Client),
        Just(DeviceRole::Runner),
        Just(DeviceRole::ClientAndRunner),
    ]
}

fn device_kind() -> impl Strategy<Value = DeviceKind> {
    prop_oneof![Just(DeviceKind::Computer), Just(DeviceKind::Phone)]
}

fn hardware_key_kind() -> impl Strategy<Value = HardwareKeyKind> {
    prop_oneof![
        Just(HardwareKeyKind::SecureEnclave),
        Just(HardwareKeyKind::Tpm),
        Just(HardwareKeyKind::StrongBox),
        Just(HardwareKeyKind::Software),
    ]
}

pub fn device_registration() -> impl Strategy<Value = DeviceRegistration> {
    (
        text(),
        device_role(),
        device_kind(),
        hardware_key_kind(),
        bytes(),
        bytes(),
    )
        .prop_map(|(name, role, kind, key_kind, signing, sealing)| {
            DeviceRegistration {
                name,
                role,
                kind,
                key_kind,
                signing_public_key: signing,
                sealing_public_key: sealing,
            }
        })
}

pub fn joining_device() -> impl Strategy<Value = JoiningDevice> {
    (
        device_registration(),
        option::of(bytes()),
        option::of(bytes()),
    )
        .prop_map(|(registration, joiner_nonce, approver_nonce)| {
            JoiningDevice {
                name: registration.name,
                role: registration.role,
                kind: registration.kind,
                key_kind: registration.key_kind,
                signing_public_key: registration.signing_public_key,
                sealing_public_key: registration.sealing_public_key,
                joiner_nonce,
                approver_nonce,
            }
        })
}

pub fn sealed_workspace_key() -> impl Strategy<Value = SealedWorkspaceKey> {
    (workspace_identifier(), bytes()).prop_map(|(workspace_id, sealed_key)| {
        SealedWorkspaceKey {
            workspace_id,
            sealed_key,
        }
    })
}

pub fn signed_peer_address() -> impl Strategy<Value = SignedPeerAddress> {
    let socket_address = (any::<[u8; 4]>(), any::<u16>())
        .prop_map(|(octets, port)| SocketAddr::from((octets, port)));
    (
        device_identifier(),
        any::<[u8; 32]>(),
        vec(socket_address, 0..MAXIMUM_ITEMS),
        option::of(text()),
        timestamp(),
        bytes(),
    )
        .prop_map(
            |(
                device_id,
                endpoint_public_key,
                direct_addresses,
                relay_url,
                published_at,
                signature,
            )| SignedPeerAddress {
                device_id,
                address: PeerAddress {
                    endpoint_public_key,
                    direct_addresses,
                    relay_url,
                },
                published_at,
                signature,
            },
        )
}

fn device() -> impl Strategy<Value = Device> {
    (
        (device_identifier(), device_registration()),
        vec(workspace_identifier(), 0..MAXIMUM_ITEMS),
        (timestamp(), timestamp()),
        option::of(device_identifier()),
        any::<bool>(),
        option::of(signed_peer_address()),
    )
        .prop_map(
            |(
                (id, registration),
                workspaces,
                (paired_at, last_seen),
                approved_by,
                revoked,
                peer_address,
            )| Device {
                id,
                name: registration.name,
                role: registration.role,
                kind: registration.kind,
                key_kind: registration.key_kind,
                signing_public_key: registration.signing_public_key,
                sealing_public_key: registration.sealing_public_key,
                workspaces,
                paired_at,
                approved_by,
                last_seen,
                revoked,
                peer_address,
            },
        )
}

fn workspace() -> impl Strategy<Value = Workspace> {
    (
        workspace_identifier(),
        text(),
        text(),
        any::<bool>(),
        vec("[a-z.~/]{1,8}", 0..MAXIMUM_ITEMS),
    )
        .prop_map(|(id, name, address, is_asking, patterns)| Workspace {
            id,
            name,
            app_server_address: address,
            approval_policy: if is_asking {
                ApprovalPolicy::AskBeforeRiskyActions
            } else {
                ApprovalPolicy::NeverAsk
            },
            protected_files: ProtectedFiles { patterns },
        })
}

pub fn account_view() -> impl Strategy<Value = AccountView> {
    (
        device(),
        vec(workspace(), 0..MAXIMUM_ITEMS),
        vec(sealed_workspace_key(), 0..MAXIMUM_ITEMS),
    )
        .prop_map(|(device, workspaces, sealed_workspace_keys)| {
            AccountView {
                device,
                workspaces,
                sealed_workspace_keys,
            }
        })
}
