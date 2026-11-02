use std::time::Duration;

use crate::identifiers::DeviceId;
use crate::server_group::{ServerGroup, ServerStanding, ServerTerm};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ProbeAnswer {
    pub server_id: DeviceId,
    pub term: Option<ServerTerm>,
    pub standing: ServerStanding,
}

#[derive(Clone, Copy, Debug)]
pub struct KeeperObservation<'observation> {
    pub group: &'observation ServerGroup,
    pub own_server_id: &'observation DeviceId,
    pub standing: ServerStanding,
    pub known_term: Option<&'observation ServerTerm>,
    pub probes: &'observation [ProbeAnswer],
    pub silence: Duration,
    pub takeover_after: Duration,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum KeeperAction {
    KeepGoing,
    Follow(DeviceId),
    StepDown(DeviceId),
    Resume,
    TakeOver { number: u64 },
}

#[must_use]
pub fn decide_keeper_action(
    observation: &KeeperObservation<'_>,
) -> KeeperAction {
    let remembered_term = choose_highest(
        observation.group.term.as_ref(),
        observation.known_term,
    );
    let probed_term = find_higher_term(
        remembered_term,
        observation.own_server_id,
        observation.probes,
    );
    let Some(leader_term) = choose_highest(remembered_term, probed_term)
    else {
        return KeeperAction::KeepGoing;
    };
    let leader = &leader_term.server_id;
    let is_own_term = leader == observation.own_server_id;
    match observation.standing {
        ServerStanding::Active if is_own_term => KeeperAction::KeepGoing,
        ServerStanding::Active => KeeperAction::StepDown(leader.clone()),
        ServerStanding::Backup if is_own_term => KeeperAction::Resume,
        ServerStanding::Backup => {
            decide_backup_action(observation, leader_term)
        }
    }
}

fn decide_backup_action(
    observation: &KeeperObservation<'_>,
    leader_term: &ServerTerm,
) -> KeeperAction {
    let leader = &leader_term.server_id;
    let is_leader_answering = observation.probes.iter().any(|probe| {
        &probe.server_id == leader && probe.standing == ServerStanding::Active
    });
    if !is_leader_answering && has_waited_for_its_turn(observation, leader) {
        let number = leader_term.number.saturating_add(1);
        return KeeperAction::TakeOver { number };
    }
    KeeperAction::Follow(leader.clone())
}

fn choose_highest<'term>(
    first: Option<&'term ServerTerm>,
    second: Option<&'term ServerTerm>,
) -> Option<&'term ServerTerm> {
    match (first, second) {
        (Some(first), Some(second)) if second.outranks(first) => Some(second),
        (None, second) => second,
        (first, _) => first,
    }
}

fn find_higher_term<'probes>(
    own_term: Option<&ServerTerm>,
    own_server_id: &DeviceId,
    probes: &'probes [ProbeAnswer],
) -> Option<&'probes ServerTerm> {
    let mut highest: Option<&ServerTerm> = None;
    for probe in probes {
        let Some(seen) = probe.term.as_ref() else {
            continue;
        };
        let names_another_server = &seen.server_id != own_server_id;
        let outranks_own = own_term.is_none_or(|own| seen.outranks(own));
        let outranks_highest = highest.is_none_or(|best| seen.outranks(best));
        if names_another_server && outranks_own && outranks_highest {
            highest = Some(seen);
        }
    }
    highest
}

fn has_waited_for_its_turn(
    observation: &KeeperObservation<'_>,
    active_server_id: &DeviceId,
) -> bool {
    let position = observation
        .group
        .takeover_position(observation.own_server_id, active_server_id);
    let Some(position) = position else {
        return false;
    };
    let turns = u32::try_from(position).unwrap_or(u32::MAX);
    observation.silence >= observation.takeover_after.saturating_mul(turns)
}
