use std::sync::Arc;
use std::time::{Duration, Instant};

use orchestration_api::server_group::ServerGroupView;
use orchestration_core::identifiers::DeviceId;
use orchestration_core::server_group::{
    ServerMember, ServerStanding, ServerTerm,
};
use orchestration_core::server_keeping::{
    KeeperAction, KeeperObservation, decide_keeper_action,
};
use orchestration_p2p::service_endpoint::ServiceEndpoint;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::server_group::sign_server_term;
use orchestration_server::{ServerError, SharedServer};
use tokio::time::sleep;

use super::keeper_signals::{
    describe_own_address, describe_server_problem, is_refusal, is_silence,
    remember_term,
};
use super::member_links::MemberLinks;
use crate::app_server_hosting::hosting_logging::log_keeper_problem;
use crate::node_error::NodeError;
use crate::server_client::PeerDialer;

const GROUP_CHECK_INTERVAL: Duration = Duration::from_secs(5);
const RETRY_PAUSE: Duration = Duration::from_secs(1);
const WHOLE_STATE_REVISION: u64 = 0;

#[derive(Debug)]
pub(crate) struct KeeperContext {
    pub(crate) server: SharedServer,
    pub(crate) endpoint: Arc<ServiceEndpoint>,
    pub(crate) identity: Arc<DeviceIdentity>,
    pub(crate) dialer: Arc<PeerDialer>,
    pub(crate) takeover_after: Duration,
}

#[derive(Debug)]
struct KeeperMemory {
    followed: Option<DeviceId>,
    known_term: Option<ServerTerm>,
    last_contact: Instant,
    links: MemberLinks,
}

pub(crate) async fn keep_group(context: KeeperContext) {
    let links = MemberLinks::new(
        Arc::clone(&context.identity),
        Arc::clone(&context.dialer),
    );
    let mut memory = KeeperMemory {
        followed: None,
        known_term: None,
        last_contact: Instant::now(),
        links,
    };
    loop {
        match run_round(&context, &mut memory).await {
            Ok(()) => {}
            Err(NodeError::RemovedFromServerGroup) => {
                log_keeper_problem(&NodeError::RemovedFromServerGroup);
                return;
            }
            Err(problem) => {
                log_keeper_problem(&problem);
                sleep(RETRY_PAUSE).await;
            }
        }
    }
}

async fn run_round(
    context: &KeeperContext,
    memory: &mut KeeperMemory,
) -> Result<(), NodeError> {
    let view = describe_group(context)?;
    memory.links.remember_addresses(&view.group);
    match view.standing {
        ServerStanding::Active => {
            sleep(GROUP_CHECK_INTERVAL).await;
            let refreshed = describe_group(context)?;
            refresh_own_address(context, memory, &refreshed).await?;
        }
        ServerStanding::Backup => {
            follow_leader(context, memory, &view).await?;
        }
    }
    decide_and_act(context, memory).await
}

async fn follow_leader(
    context: &KeeperContext,
    memory: &mut KeeperMemory,
    view: &ServerGroupView,
) -> Result<(), NodeError> {
    let Some(leader) = choose_leader(memory, view) else {
        return Ok(());
    };
    if leader == context.server.device_id() {
        return Ok(());
    }
    let is_term_server = view.group.active_server_id() == Some(&leader);
    let after_revision = if is_term_server {
        view.revision
    } else {
        WHOLE_STATE_REVISION
    };
    match memory.links.fetch_replica(&leader, after_revision).await {
        Ok(Some(replica_bytes)) => context
            .server
            .install_replica(&replica_bytes, &leader)
            .map_err(|problem| describe_server_problem(&problem))?,
        Ok(None) => {}
        Err(problem) if is_silence(&problem) => {
            sleep(RETRY_PAUSE).await;
            return Ok(());
        }
        Err(problem) if is_refusal(&problem) => {
            return Err(NodeError::RemovedFromServerGroup);
        }
        Err(problem) => return Err(problem),
    }
    memory.last_contact = Instant::now();
    let refreshed = describe_group(context)?;
    refresh_own_address(context, memory, &refreshed).await
}

async fn decide_and_act(
    context: &KeeperContext,
    memory: &mut KeeperMemory,
) -> Result<(), NodeError> {
    let view = describe_group(context)?;
    let own_server_id = context.server.device_id();
    let silence = memory.last_contact.elapsed();
    let names_this_server =
        view.group.active_server_id() == Some(&own_server_id);
    let needs_probes = match view.standing {
        ServerStanding::Active => view.group.has_backups(),
        ServerStanding::Backup => {
            names_this_server || silence >= context.takeover_after
        }
    };
    let probes = if needs_probes {
        memory
            .links
            .probe_members(&view.group, &own_server_id)
            .await
    } else {
        Vec::new()
    };
    remember_term(&mut memory.known_term, view.group.term.as_ref());
    for probe in &probes {
        remember_term(&mut memory.known_term, probe.term.as_ref());
    }
    let action = decide_keeper_action(&KeeperObservation {
        group: &view.group,
        own_server_id: &own_server_id,
        standing: view.standing,
        known_term: memory.known_term.as_ref(),
        probes: &probes,
        silence,
        takeover_after: context.takeover_after,
    });
    apply_action(context, memory, action)
}

fn apply_action(
    context: &KeeperContext,
    memory: &mut KeeperMemory,
    action: KeeperAction,
) -> Result<(), NodeError> {
    let server = &context.server;
    let describe = |problem: ServerError| describe_server_problem(&problem);
    match action {
        KeeperAction::KeepGoing => {}
        KeeperAction::Follow(leader) => {
            if memory.followed.as_ref() != Some(&leader) {
                memory.last_contact = Instant::now();
            }
            memory.followed = Some(leader);
        }
        KeeperAction::StepDown(leader) => {
            server.step_down().map_err(describe)?;
            memory.followed = Some(leader);
            memory.last_contact = Instant::now();
        }
        KeeperAction::Resume => {
            server.resume_as_active().map_err(describe)?;
            memory.followed = None;
        }
        KeeperAction::TakeOver { number } => {
            let term = sign_server_term(
                &context.identity,
                number,
                server.device_id(),
            );
            server.take_over(&term).map_err(describe)?;
            memory.followed = None;
            memory.known_term = Some(term);
        }
    }
    Ok(())
}

async fn refresh_own_address(
    context: &KeeperContext,
    memory: &mut KeeperMemory,
    view: &ServerGroupView,
) -> Result<(), NodeError> {
    let own_server_id = context.server.device_id();
    let Some(own_member) = view.group.find_member(&own_server_id) else {
        return Ok(());
    };
    let current_address = describe_own_address(&context.endpoint);
    if own_member.address == current_address {
        return Ok(());
    }
    let member = ServerMember {
        membership: own_member.membership.clone(),
        address: current_address,
    };
    if view.standing == ServerStanding::Active {
        let device_id = context.identity.device_id();
        context
            .server
            .register_member(&device_id, &member)
            .map_err(|problem| describe_server_problem(&problem))?;
        return Ok(());
    }
    let Some(leader) = choose_leader(memory, view) else {
        return Ok(());
    };
    if leader == own_server_id {
        return Ok(());
    }
    memory.links.send_own_member(&leader, member).await
}

fn choose_leader(
    memory: &KeeperMemory,
    view: &ServerGroupView,
) -> Option<DeviceId> {
    memory
        .followed
        .clone()
        .or_else(|| view.group.active_server_id().cloned())
}

fn describe_group(
    context: &KeeperContext,
) -> Result<ServerGroupView, NodeError> {
    context
        .server
        .describe_group()
        .map_err(|problem| describe_server_problem(&problem))
}
