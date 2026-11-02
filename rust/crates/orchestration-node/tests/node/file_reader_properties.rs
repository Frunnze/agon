use chrono::{DateTime, Duration, Utc};
use orchestration_core::device::{
    Device, DeviceRole, HardwareKeyKind, Runner, RunnerLink, SandboxKind,
};
use orchestration_core::identifiers::{DeviceId, ProjectId, WorkspaceId};
use orchestration_core::peer_address::PeerAddress;
use orchestration_core::workspace::{AgentAccess, Project, Repository};
use orchestration_node::live_link_messages::RepositoryReference;
use orchestration_node::node_error::NodeError;
use orchestration_node::runner_bridge::{
    check_file_reader, check_reader_access,
};
use orchestration_node::views::find_repository_holders;
use orchestration_security::identity::{
    DeviceIdentity, IDENTITY_SECRET_LENGTH,
};
use orchestration_security::peer_addresses::sign_peer_address;
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::support::entity_strategies::sample_time;
use crate::support::test_device::fail;

const ADDRESS: &str = "github.com/acme/app";
const OTHER_ADDRESS: &str = "github.com/acme/api";
const READER_KEY: [u8; 32] = [42; 32];
const STRANGER_KEY: [u8; 32] = [43; 32];

#[derive(Clone, Copy, Debug)]
struct ReaderShape {
    role: DeviceRole,
    revoked: bool,
    in_workspace: bool,
    signs_address: bool,
}

fn workspace() -> WorkspaceId {
    WorkspaceId(Uuid::from_u128(7))
}

fn project() -> Project {
    Project {
        id: ProjectId(Uuid::from_u128(9)),
        workspace_id: workspace(),
        name: "acme-app".to_owned(),
        repositories: vec![Repository {
            address: ADDRESS.to_owned(),
            default_branch: "main".to_owned(),
            agent_access: AgentAccess::ReadOnly,
        }],
    }
}

fn build_device(shape: ReaderShape, seed: u8) -> Result<Device, String> {
    let secret = [seed; IDENTITY_SECRET_LENGTH];
    let identity = DeviceIdentity::from_secret_bytes(&secret)
        .map_err(|problem| problem.to_string())?;
    let address = PeerAddress {
        endpoint_public_key: READER_KEY,
        direct_addresses: Vec::new(),
        relay_url: None,
    };
    let mut signed = sign_peer_address(&identity, &address, sample_time());
    if !shape.signs_address {
        signed.signature = vec![0; signed.signature.len()];
    }
    let public = identity.public_identity();
    let workspaces = if shape.in_workspace {
        vec![workspace()]
    } else {
        Vec::new()
    };
    Ok(Device {
        id: public.device_id,
        name: "laptop".to_owned(),
        role: shape.role,
        key_kind: HardwareKeyKind::Software,
        signing_public_key: public.signing_public_key,
        sealing_public_key: public.sealing_public_key,
        workspaces,
        paired_at: sample_time(),
        approved_by: None,
        last_seen: sample_time(),
        revoked: shape.revoked,
        peer_address: Some(signed),
    })
}

fn reader_shape() -> impl Strategy<Value = ReaderShape> {
    let role = prop_oneof![
        Just(DeviceRole::Client),
        Just(DeviceRole::Runner),
        Just(DeviceRole::ClientAndRunner),
    ];
    (role, any::<bool>(), any::<bool>(), any::<bool>()).prop_map(
        |(role, revoked, in_workspace, signs_address)| ReaderShape {
            role,
            revoked,
            in_workspace,
            signs_address,
        },
    )
}

fn reference(address: &str) -> RepositoryReference {
    RepositoryReference {
        project_id: project().id,
        address: address.to_owned(),
    }
}

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
        sandbox: SandboxKind::LocalProcess,
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
