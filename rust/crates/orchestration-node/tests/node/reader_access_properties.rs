use orchestration_core::device::DeviceRole;
use orchestration_node::node_error::NodeError;
use orchestration_node::runner_bridge::{
    check_file_reader, check_reader_access,
};
use proptest::prelude::*;

use crate::support::file_reader_samples::{
    ADDRESS, READER_KEY, ReaderShape, build_device, project, reader_shape,
    reference,
};
use crate::support::test_device::fail;

proptest! {
    #[test]
    fn test_check_reader_access_property_matches_the_peer_link_check(
        shape in reader_shape(),
        seed in 1_u8..200,
    ) {
        let signed_shape = ReaderShape {
            signs_address: true,
            ..shape
        };
        let device = build_device(signed_shape, seed).map_err(fail)?;
        let devices = [device.clone()];

        let own_verdict =
            check_reader_access(&device, &[project()], &reference(ADDRESS));
        let peer_verdict = check_file_reader(
            &devices,
            &[project()],
            &READER_KEY,
            &reference(ADDRESS),
        );

        prop_assert_eq!(
            own_verdict.is_ok(),
            peer_verdict.is_ok(),
            "{:?} {:?}",
            own_verdict,
            peer_verdict
        );
        if let Err(problem) = own_verdict {
            prop_assert!(matches!(problem, NodeError::UntrustedFileReader));
        }
    }

    #[test]
    fn test_check_reader_access_property_refuses_other_repositories(
        address in "[a-z./]{1,30}",
        seed in 1_u8..200,
    ) {
        prop_assume!(address != ADDRESS);
        let shape = ReaderShape {
            role: DeviceRole::ClientAndRunner,
            revoked: false,
            in_workspace: true,
            signs_address: false,
        };
        let device = build_device(shape, seed).map_err(fail)?;

        let verdict =
            check_reader_access(&device, &[project()], &reference(&address));

        prop_assert!(matches!(
            verdict,
            Err(NodeError::RepositoryOutsideProject(_))
        ));
    }
}
