use std::time::{Duration, Instant};

use proptest::prelude::*;

use crate::hosting_desk::{
    heavy_cases, host_a_server, read_hosted_peer_address, shared_hosting,
};
use crate::local_announcements::{
    describe_announced_address, watch_for_announcement,
};
use crate::restart_support::{
    check_health_at, read_hosted_ipv4_port, read_ipv4_peer_port,
    restart_keeping_the_port_free, restart_with_the_port_taken,
    retry_until_reached, wait_for_the_new_announcement,
};
use crate::support::test_device::{TestDevice, fail};

const UNREACHABLE_LIMIT: Duration = Duration::from_secs(30);

fn wait_until_announced(device: &TestDevice) -> Result<(), TestCaseError> {
    let address = read_hosted_peer_address(device).map_err(fail)?;
    let wanted = describe_announced_address(&address);
    watch_for_announcement(&wanted).map_err(fail)?;
    Ok(())
}

proptest! {
    #![proptest_config(heavy_cases(1))]

    #[test]
    fn test_find_moved_server_property_the_old_address_reaches_a_moved_one(
        _round in 0_u8..1,
    ) {
        let hosting = host_a_server().map_err(fail)?;
        let moved =
            restart_with_the_port_taken(hosting.device).map_err(fail)?;
        wait_for_the_new_announcement(&moved).map_err(fail)?;

        let answered =
            retry_until_reached(|| check_health_at(&moved.old_address));

        prop_assert_eq!(answered, Ok(()));
    }

    #[test]
    fn test_find_moved_server_property_a_stopped_server_fails_in_time(
        _round in 0_u8..1,
    ) {
        let hosting = host_a_server().map_err(fail)?;
        let old_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;
        let _stopped = hosting.device.stop();

        let asked_at = Instant::now();
        let answered = check_health_at(&old_address);
        let waited = asked_at.elapsed();

        prop_assert!(answered.is_err(), "a stopped server answered");
        prop_assert!(waited <= UNREACHABLE_LIMIT, "{waited:?}");
    }

    #[test]
    fn test_find_moved_server_property_another_server_is_never_taken(
        _round in 0_u8..1,
    ) {
        let other = shared_hosting().map_err(fail)?;
        wait_until_announced(&other.device)?;
        let hosting = host_a_server().map_err(fail)?;
        let old_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;
        let _stopped = hosting.device.stop();

        let answered = check_health_at(&old_address);

        prop_assert!(answered.is_err(), "another server answered for it");
    }

    #[test]
    fn test_find_peer_address_property_the_announcement_names_the_move(
        _round in 0_u8..1,
    ) {
        let hosting = host_a_server().map_err(fail)?;
        let moved =
            restart_with_the_port_taken(hosting.device).map_err(fail)?;
        let old_port = read_ipv4_peer_port(&moved.old_address).map_err(fail)?;
        let moved_port = read_hosted_ipv4_port(&moved.device).map_err(fail)?;

        let announced = wait_for_the_new_announcement(&moved).map_err(fail)?;

        prop_assert_eq!(announced.port, moved_port);
        prop_assert_ne!(announced.port, old_port);
    }

    #[test]
    fn test_find_peer_address_property_a_plain_restart_announces_the_port(
        restart_count in 1_usize..3,
    ) {
        let hosting = host_a_server().map_err(fail)?;
        let mut device = hosting.device;
        let first_port = read_hosted_ipv4_port(&device).map_err(fail)?;

        for _ in 0..restart_count {
            let restarted =
                restart_keeping_the_port_free(device).map_err(fail)?;
            let announced =
                wait_for_the_new_announcement(&restarted).map_err(fail)?;
            prop_assert_eq!(announced.port, first_port);
            device = restarted.device;
        }
    }

    #[test]
    fn test_find_peer_address_property_keeps_the_endpoint_key(
        _round in 0_u8..1,
    ) {
        let hosting = host_a_server().map_err(fail)?;
        let moved =
            restart_with_the_port_taken(hosting.device).map_err(fail)?;
        wait_for_the_new_announcement(&moved).map_err(fail)?;
        let mut stranger_address = moved.old_address.clone();
        stranger_address.endpoint_public_key[0] ^= 1;

        let answered_as_itself =
            retry_until_reached(|| check_health_at(&moved.old_address));
        let answered_as_stranger = check_health_at(&stranger_address);

        prop_assert_eq!(answered_as_itself, Ok(()));
        prop_assert!(answered_as_stranger.is_err(), "a wrong key answered");
    }
}
