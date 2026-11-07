use orchestration_core::server_group::{ServerGroup, ServerMember};
use orchestration_node::device_files::DeviceFiles;
use orchestration_security::identity::device_id_for;
use orchestration_security::server_group::{
    verify_server_membership, verify_server_term,
};
use proptest::prelude::*;

use crate::backup_group::shared_backup_group;
use crate::hosting_desk::{
    heavy_cases, host_a_server, read_own_group, shared_hosting,
};
use crate::support::hosting_steps::HostingDevice;
use crate::support::server_backups::read_hosted_state;
use crate::support::test_device::{TestDevice, fail};

const FOUNDING_TERM_NUMBER: u64 = 1;
const FOUNDING_AUDIT_TEXT: &str = "hosts the active app server";
const GROUP_PAIR_SIZE: usize = 2;

fn load_saved_group(
    device: &TestDevice,
) -> Result<ServerGroup, TestCaseError> {
    let files =
        DeviceFiles::open(device.data_directory.path()).map_err(fail)?;
    let saved = files.load_server_group().map_err(fail)?;
    saved.ok_or_else(|| fail("the device saved no server group"))
}

fn list_server_ids(group: &ServerGroup) -> Vec<String> {
    let mut server_ids: Vec<String> = Vec::new();
    for member in &group.members {
        server_ids.push(member.membership.server_id.0.clone());
    }
    server_ids.sort();
    server_ids
}

fn find_member_of(
    group: &ServerGroup,
    device: &TestDevice,
) -> Result<ServerMember, TestCaseError> {
    let identity = device.load_identity().map_err(fail)?;
    let member = group.find_member_of_device(&identity.device_id());
    member
        .cloned()
        .ok_or_else(|| fail("the device keeps no server"))
}

fn count_foundings(device: &TestDevice) -> Result<usize, TestCaseError> {
    let state = read_hosted_state(device).map_err(fail)?;
    let audit_text = state["audit_log"].to_string();
    Ok(audit_text.matches(FOUNDING_AUDIT_TEXT).count())
}

proptest! {
    #![proptest_config(heavy_cases(2))]

    #[test]
    fn test_keep_server_group_property_saves_the_founded_group(
        _round in 0_u8..2,
    ) {
        let hosting = shared_hosting().map_err(fail)?;

        let view =
            read_own_group(&hosting.device, hosting.port).map_err(fail)?;
        let saved = load_saved_group(&hosting.device)?;

        prop_assert_eq!(&saved.term, &view.group.term);
        prop_assert_eq!(list_server_ids(&saved), list_server_ids(&view.group));
    }

    #[test]
    fn test_keep_server_group_property_restarts_keep_one_term(
        restart_count in 1_usize..3,
    ) {
        let HostingDevice { mut device, port, .. } =
            host_a_server().map_err(fail)?;
        let founded = read_own_group(&device, port).map_err(fail)?;

        for _ in 0..restart_count {
            device = device.stop_and_start_again().map_err(fail)?;
            let view = read_own_group(&device, port).map_err(fail)?;
            prop_assert_eq!(&view.group.term, &founded.group.term);
            prop_assert_eq!(
                list_server_ids(&view.group),
                list_server_ids(&founded.group)
            );
        }
    }

    #[test]
    fn test_keep_server_group_property_a_backup_saves_the_shared_group(
        _round in 0_u8..2,
    ) {
        let group = shared_backup_group().map_err(fail)?;

        let active_view = group.read_active_group().map_err(fail)?;
        let saved = load_saved_group(&group.backup)?;

        prop_assert_eq!(&saved.term, &active_view.group.term);
        prop_assert_eq!(saved.members.len(), GROUP_PAIR_SIZE);
        prop_assert_eq!(
            list_server_ids(&saved),
            list_server_ids(&active_view.group)
        );
    }

    #[test]
    fn test_sign_own_member_property_the_founder_membership_verifies(
        _round in 0_u8..2,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let identity = hosting.device.load_identity().map_err(fail)?;
        let view =
            read_own_group(&hosting.device, hosting.port).map_err(fail)?;

        let founder = find_member_of(&view.group, &hosting.device)?;

        let device_key = identity.public_identity().signing_public_key;
        let verified =
            verify_server_membership(&founder.membership, &device_key);
        prop_assert!(verified.is_ok(), "{verified:?}");
        prop_assert_eq!(founder.membership.device_id, identity.device_id());
    }

    #[test]
    fn test_sign_own_member_property_the_address_carries_the_signed_key(
        _round in 0_u8..2,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let view =
            read_own_group(&hosting.device, hosting.port).map_err(fail)?;

        let founder = find_member_of(&view.group, &hosting.device)?;

        prop_assert!(founder.has_signed_address());
        let key_id =
            device_id_for(&founder.membership.server_signing_public_key);
        prop_assert_eq!(key_id, founder.membership.server_id);
        prop_assert!(!founder.address.direct_addresses.is_empty());
    }

    #[test]
    fn test_sign_own_member_property_the_backup_membership_verifies(
        _round in 0_u8..2,
    ) {
        let group = shared_backup_group().map_err(fail)?;
        let backup_identity = group.backup.load_identity().map_err(fail)?;
        let view = group.read_active_group().map_err(fail)?;

        let backup = find_member_of(&view.group, &group.backup)?;
        let founder = find_member_of(&view.group, &group.hosting.device)?;

        let device_key = backup_identity.public_identity().signing_public_key;
        let verified =
            verify_server_membership(&backup.membership, &device_key);
        prop_assert!(verified.is_ok(), "{verified:?}");
        prop_assert!(backup.has_signed_address());
        let backup_joined = backup.membership.joined_at;
        prop_assert!(backup_joined >= founder.membership.joined_at);
    }

    #[test]
    fn test_found_group_if_missing_property_founds_term_one_for_itself(
        _round in 0_u8..2,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let identity = hosting.device.load_identity().map_err(fail)?;
        let view =
            read_own_group(&hosting.device, hosting.port).map_err(fail)?;

        let term = view.group.term.clone();
        let term = term.ok_or_else(|| fail("the group has no term"))?;
        let founder = find_member_of(&view.group, &hosting.device)?;

        prop_assert_eq!(term.number, FOUNDING_TERM_NUMBER);
        prop_assert_eq!(&term.server_id, &founder.membership.server_id);
        prop_assert_eq!(&term.claimed_by, &identity.device_id());
        let device_key = identity.public_identity().signing_public_key;
        prop_assert!(verify_server_term(&term, &device_key).is_ok());
        let signer = view.group.audit_signers.get(&term.server_id);
        prop_assert_eq!(
            signer,
            Some(&founder.membership.server_signing_public_key)
        );
    }

    #[test]
    fn test_found_group_if_missing_property_never_founds_twice(
        restart_count in 1_usize..3,
    ) {
        let HostingDevice { mut device, .. } = host_a_server().map_err(fail)?;

        for _ in 0..restart_count {
            device = device.stop_and_start_again().map_err(fail)?;
        }
        let foundings = count_foundings(&device)?;

        prop_assert_eq!(foundings, 1);
    }

    #[test]
    fn test_found_group_if_missing_property_a_backup_keeps_the_active_term(
        _round in 0_u8..2,
    ) {
        let group = shared_backup_group().map_err(fail)?;

        let active_view = group.read_active_group().map_err(fail)?;
        let backup_view = group.read_backup_group().map_err(fail)?;
        let backup_member = find_member_of(&backup_view.group, &group.backup)?;

        prop_assert_eq!(&backup_view.group.term, &active_view.group.term);
        prop_assert_ne!(
            backup_view.group.active_server_id(),
            Some(&backup_member.membership.server_id)
        );
    }
}
