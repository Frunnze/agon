use chrono::{DateTime, Duration, Utc};
use orchestration_core::agent_place::AgentPlace;
use orchestration_core::device::{DeviceRole, Runner, RunnerLink};
use orchestration_core::identifiers::DeviceId;
use orchestration_node::node_error::NodeError;
use orchestration_node::runner_bridge::check_file_reader;
use orchestration_node::views::find_repository_holders;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::support::entity_strategies::sample_time;
use crate::support::file_reader_samples::{
    ADDRESS, READER_KEY, ReaderShape, build_device, project, reader_shape,
    reference,
};
use crate::support::test_device::fail;

const OTHER_ADDRESS: &str = "github.com/acme/api";
const STRANGER_KEY: [u8; 32] = [43; 32];

fn build_runner(device_id: &DeviceId, online: bool, cached: bool) -> Runner {
    let cached_repositories = if cached {
        vec![OTHER_ADDRESS.to_owned(), ADDRESS.to_owned()]
    } else {
        vec![OTHER_ADDRESS.to_owned()]
    };
    Runner {
        device_id: device_id.clone(),
        labels: Vec::new(),
        slots_total: 1,
        slots_busy: 0,
        link: RunnerLink::Direct,
        online,
        accepting_new_runs: true,
        offers: vec![AgentPlace::LocalProcess],
        allowed_hosts: Vec::new(),
        cached_repositories,
    }
}

fn shift(moment: DateTime<Utc>, minutes: i64) -> DateTime<Utc> {
    moment - Duration::minutes(minutes)
}

proptest! {
    #[test]
    fn test_check_file_reader_property_admits_only_trusted_clients(
        shape in reader_shape(),
        seed in 1_u8..200,
    ) {
        let device = build_device(shape, seed).map_err(fail)?;

        let verdict = check_file_reader(
            &[device],
            &[project()],
            &READER_KEY,
            &reference(ADDRESS),
        );

        let is_client = shape.role != DeviceRole::Runner;
        let is_trusted = is_client
            && !shape.revoked
            && shape.in_workspace
            && shape.signs_address;
        prop_assert_eq!(verdict.is_ok(), is_trusted, "{:?}", verdict);
        if let Err(problem) = verdict {
            prop_assert!(matches!(problem, NodeError::UntrustedFileReader));
        }
    }

    #[test]
    fn test_check_file_reader_property_refuses_unknown_keys(
        shape in reader_shape(),
        seed in 1_u8..200,
    ) {
        let device = build_device(shape, seed).map_err(fail)?;

        let verdict = check_file_reader(
            &[device],
            &[project()],
            &STRANGER_KEY,
            &reference(ADDRESS),
        );

        prop_assert!(matches!(verdict, Err(NodeError::UntrustedFileReader)));
    }

    #[test]
    fn test_check_file_reader_property_refuses_other_repositories(
        address in "[a-z./]{1,30}",
        seed in 1_u8..200,
    ) {
        prop_assume!(address != ADDRESS);
        let shape = ReaderShape {
            role: DeviceRole::Client,
            revoked: false,
            in_workspace: true,
            signs_address: true,
        };
        let device = build_device(shape, seed).map_err(fail)?;

        let verdict = check_file_reader(
            &[device],
            &[project()],
            &READER_KEY,
            &reference(&address),
        );

        prop_assert!(matches!(
            verdict,
            Err(NodeError::RepositoryOutsideProject(_))
        ));
    }

    #[test]
    fn test_find_repository_holders_property_lists_live_copies_only(
        runner_shapes in vec(any::<(bool, bool, bool)>(), 0..6),
    ) {
        let mut devices = Vec::new();
        let mut runners = Vec::new();
        for (index, shape) in runner_shapes.iter().enumerate() {
            let (online, cached, revoked) = shape;
            let seed = u8::try_from(index + 1).map_err(fail)?;
            let shape = ReaderShape {
                role: DeviceRole::Runner,
                revoked: *revoked,
                in_workspace: true,
                signs_address: true,
            };
            let mut device =
                build_device(shape, seed).map_err(fail)?;
            device.last_seen =
                shift(sample_time(), i64::try_from(index).unwrap_or(0));
            runners.push(build_runner(&device.id, *online, *cached));
            devices.push(device);
        }

        let holders = find_repository_holders(&runners, &devices, ADDRESS);

        let expected = runner_shapes
            .iter()
            .filter(|(_, cached, revoked)| *cached && !*revoked)
            .count();
        prop_assert_eq!(holders.len(), expected);
        for pair in holders.windows(2) {
            prop_assert!(pair[0].last_seen >= pair[1].last_seen);
        }
        for holder in &holders {
            let runner = runners
                .iter()
                .find(|runner| runner.device_id == holder.device_id);
            let online = runner.map(|runner| runner.online);
            prop_assert_eq!(online, Some(holder.online));
        }
    }
}
