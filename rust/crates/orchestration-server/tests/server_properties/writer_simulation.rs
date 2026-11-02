use std::time::Duration;

use axum::http::StatusCode;
use orchestration_api::catalog::SaveProjectRequest;
use orchestration_api::routes::PROJECTS;
use orchestration_core::device::DeviceRole;
use orchestration_core::identifiers::DeviceId;
use orchestration_core::server_group::{ServerStanding, ServerTerm};
use orchestration_core::server_keeping::{
    KeeperAction, KeeperObservation, ProbeAnswer, decide_keeper_action,
};
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::server_group::sign_server_term;

use crate::fixtures::{
    Account, OWNER_SEED, identity_from_seed, pair_device, sample_project,
};
use crate::server_group_fixtures::{
    GroupFixture, join_group, member_for, start_group,
};
use crate::test_client::{TestServer, block_on};

const THIRD_DEVICE_SEED: u8 = 52;
const THIRD_ENDPOINT_FILL: u8 = 9;
pub const NODE_COUNT: usize = 3;
const TICK: Duration = Duration::from_secs(10);
const TAKEOVER_AFTER: Duration = Duration::from_secs(30);

#[derive(Debug)]
pub struct SimulatedNode {
    pub device: DeviceIdentity,
    pub server: TestServer,
    pub is_running: bool,
    pub followed: Option<DeviceId>,
    pub silence: Duration,
    pub known_term: Option<ServerTerm>,
}

#[derive(Debug)]
pub struct Simulation {
    pub nodes: Vec<SimulatedNode>,
    pub cut_links: Vec<(usize, usize)>,
    pub account: Account,
}

pub fn start_simulation() -> Simulation {
    let GroupFixture {
        active,
        account,
        backup,
        backup_device,
    } = block_on(start_group());
    let third_device = identity_from_seed(THIRD_DEVICE_SEED);
    block_on(pair_device(
        &active,
        &account,
        &third_device,
        "third-mac",
        DeviceRole::Client,
    ));
    let third = TestServer::start();
    third
        .server
        .step_down()
        .expect("the third server steps down");
    let member =
        member_for(&third_device, &third, THIRD_ENDPOINT_FILL, active.now());
    block_on(join_group(&active, &third_device, member));
    let owner = identity_from_seed(OWNER_SEED);
    let mut simulation = Simulation {
        nodes: Vec::new(),
        cut_links: Vec::new(),
        account,
    };
    for (device, server) in [
        (owner, active),
        (backup_device, backup),
        (third_device, third),
    ] {
        simulation.nodes.push(SimulatedNode {
            device,
            server,
            is_running: true,
            followed: None,
            silence: Duration::ZERO,
            known_term: None,
        });
    }
    simulation
}

pub fn can_reach(simulation: &Simulation, from: usize, to: usize) -> bool {
    let target_runs = simulation.nodes[to].is_running;
    let is_cut = simulation.cut_links.contains(&(from.min(to), from.max(to)));
    target_runs && !is_cut
}

pub fn find_node(
    simulation: &Simulation,
    server_id: &DeviceId,
) -> Option<usize> {
    simulation
        .nodes
        .iter()
        .position(|node| &node.server.server.device_id() == server_id)
}

pub fn probe_others(
    simulation: &Simulation,
    index: usize,
) -> Vec<ProbeAnswer> {
    let mut probes = Vec::new();
    for (other, node) in simulation.nodes.iter().enumerate() {
        if other == index || !can_reach(simulation, index, other) {
            continue;
        }
        let state = node.server.server.snapshot_state().expect("state reads");
        probes.push(ProbeAnswer {
            server_id: node.server.server.device_id(),
            term: state.server_group.term,
            standing: node.server.server.standing(),
        });
    }
    probes
}

pub fn copy_from_followed(simulation: &mut Simulation, index: usize) {
    let node = &simulation.nodes[index];
    let group = node.server.server.snapshot_state().expect("state reads");
    let Some(term) = group.server_group.term else {
        return;
    };
    let followed = node.followed.clone().unwrap_or(term.server_id);
    let source = find_node(simulation, &followed);
    let reachable_source = source.filter(|source| {
        can_reach(simulation, index, *source)
            && simulation.nodes[*source].server.server.standing()
                == ServerStanding::Active
    });
    let Some(source) = reachable_source else {
        simulation.nodes[index].silence += TICK;
        return;
    };
    let source_state = simulation.nodes[source]
        .server
        .server
        .snapshot_state()
        .expect("state reads");
    let replica_bytes = serde_json::to_vec(&source_state).expect("encodes");
    let _not_newer = simulation.nodes[index]
        .server
        .server
        .install_replica(&replica_bytes, &followed);
    simulation.nodes[index].silence = Duration::ZERO;
}

pub fn remember_term(node: &mut SimulatedNode, seen: Option<&ServerTerm>) {
    let Some(seen) = seen else {
        return;
    };
    let is_higher = node
        .known_term
        .as_ref()
        .is_none_or(|known| seen.outranks(known));
    if is_higher {
        node.known_term = Some(seen.clone());
    }
}

pub fn run_keeper(simulation: &mut Simulation, index: usize) {
    let server = &simulation.nodes[index].server.server;
    if server.standing() == ServerStanding::Backup {
        copy_from_followed(simulation, index);
    }
    let probes = probe_others(simulation, index);
    let node = &mut simulation.nodes[index];
    let state = node.server.server.snapshot_state().expect("state reads");
    remember_term(node, state.server_group.term.as_ref());
    for probe in &probes {
        remember_term(node, probe.term.as_ref());
    }
    let own_server_id = node.server.server.device_id();
    let action = decide_keeper_action(&KeeperObservation {
        group: &state.server_group,
        own_server_id: &own_server_id,
        standing: node.server.server.standing(),
        known_term: node.known_term.as_ref(),
        probes: &probes,
        silence: node.silence,
        takeover_after: TAKEOVER_AFTER,
    });
    apply_action(node, action);
}

pub fn apply_action(node: &mut SimulatedNode, action: KeeperAction) {
    let server = &node.server.server;
    match action {
        KeeperAction::KeepGoing => {}
        KeeperAction::Follow(leader) => {
            if node.followed.as_ref() != Some(&leader) {
                node.silence = Duration::ZERO;
            }
            node.followed = Some(leader);
        }
        KeeperAction::StepDown(leader) => {
            server.step_down().expect("the server steps down");
            node.followed = Some(leader);
            node.silence = Duration::ZERO;
        }
        KeeperAction::Resume => {
            server.resume_as_active().expect("the server resumes");
        }
        KeeperAction::TakeOver { number } => {
            let term =
                sign_server_term(&node.device, number, server.device_id());
            server.take_over(&term).expect("the server takes over");
            node.followed = None;
            node.known_term = Some(term);
        }
    }
}

pub fn try_write(simulation: &Simulation, index: usize) -> Result<(), String> {
    let node = &simulation.nodes[index];
    let owner = &simulation.nodes[0].device;
    let request = SaveProjectRequest {
        project: sample_project(simulation.account.workspace_id),
    };
    let response = block_on(node.server.post(owner, PROJECTS, &request));
    if response.status != StatusCode::OK {
        return Ok(());
    }
    let state = node.server.server.snapshot_state().expect("state reads");
    let term = state.server_group.term.ok_or("a write without a term")?;
    if term.server_id != node.server.server.device_id() {
        return Err(format!("a write in another server's term {term:?}"));
    }
    if node.known_term.as_ref() != Some(&term) {
        return Err(format!("a write in an outranked term {term:?}"));
    }
    Ok(())
}

pub fn run_tick(simulation: &mut Simulation) -> Result<(), String> {
    for index in 0..NODE_COUNT {
        if simulation.nodes[index].is_running {
            run_keeper(simulation, index);
            try_write(simulation, index)?;
        }
    }
    Ok(())
}

pub fn count_active(simulation: &Simulation) -> usize {
    simulation
        .nodes
        .iter()
        .filter(|node| node.server.server.standing() == ServerStanding::Active)
        .count()
}

pub fn restart_node(node: &mut SimulatedNode) {
    node.server = node.server.restart();
    node.is_running = true;
    node.followed = None;
    node.silence = Duration::ZERO;
    node.known_term = None;
}
