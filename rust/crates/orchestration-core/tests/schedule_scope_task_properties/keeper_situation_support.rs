use std::time::Duration;

use orchestration_core::server_group::{
    ServerGroup, ServerStanding, ServerTerm,
};
use orchestration_core::server_keeping::{
    KeeperAction, KeeperObservation, ProbeAnswer, decide_keeper_action,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::server_group_support::{
    MOST_TERM_NUMBER, SERVER_NAMES, group_of, join_plan, members_of, server,
    term,
};

pub const MOST_PROBES: usize = 5;
pub const MOST_SILENCE_SECONDS: u64 = 300;
const MOST_TAKEOVER_SECONDS: u64 = 60;

#[derive(Clone, Debug)]
pub struct Situation {
    pub group: ServerGroup,
    pub own_name: &'static str,
    pub standing: ServerStanding,
    pub known_term: Option<ServerTerm>,
    pub probes: Vec<ProbeAnswer>,
    pub silence: Duration,
    pub takeover_after: Duration,
}

pub fn decide(situation: &Situation) -> KeeperAction {
    let own_server_id = server(situation.own_name);
    decide_keeper_action(&KeeperObservation {
        group: &situation.group,
        own_server_id: &own_server_id,
        standing: situation.standing,
        known_term: situation.known_term.as_ref(),
        probes: &situation.probes,
        silence: situation.silence,
        takeover_after: situation.takeover_after,
    })
}

pub fn server_name() -> impl Strategy<Value = &'static str> {
    prop::sample::select(SERVER_NAMES.to_vec())
}

pub fn any_term() -> impl Strategy<Value = ServerTerm> {
    (0..MOST_TERM_NUMBER, server_name())
        .prop_map(|(number, name)| term(number, name))
}

pub fn standing() -> impl Strategy<Value = ServerStanding> {
    prop_oneof![Just(ServerStanding::Active), Just(ServerStanding::Backup)]
}

pub fn probe() -> impl Strategy<Value = ProbeAnswer> {
    (server_name(), proptest::option::of(any_term()), standing()).prop_map(
        |(name, seen_term, standing)| ProbeAnswer {
            server_id: server(name),
            term: seen_term,
            standing,
        },
    )
}

pub fn seconds(most: u64) -> impl Strategy<Value = Duration> {
    (0..=most).prop_map(Duration::from_secs)
}

pub fn situation() -> impl Strategy<Value = Situation> {
    (
        join_plan(),
        proptest::option::of(any_term()),
        server_name(),
        standing(),
        proptest::option::of(any_term()),
        vec(probe(), 0..MOST_PROBES),
        seconds(MOST_SILENCE_SECONDS),
        seconds(MOST_TAKEOVER_SECONDS),
    )
        .prop_map(
            |(
                plan,
                group_term,
                own_name,
                standing,
                known_term,
                probes,
                silence,
                takeover_after,
            )| Situation {
                group: group_of(group_term, members_of(&plan)),
                own_name,
                standing,
                known_term,
                probes,
                silence,
                takeover_after,
            },
        )
}

pub fn backup_situation() -> impl Strategy<Value = Situation> {
    situation().prop_map(|situation| Situation {
        standing: ServerStanding::Backup,
        ..situation
    })
}

pub fn remembered_leader(situation: &Situation) -> Option<ServerTerm> {
    let group_term = situation.group.term.clone();
    let Some(known) = situation.known_term.clone() else {
        return group_term;
    };
    let Some(remembered) = group_term else {
        return Some(known);
    };
    if known.outranks(&remembered) {
        return Some(known);
    }
    Some(remembered)
}

pub fn silenced(situation: &Situation) -> Situation {
    Situation {
        probes: Vec::new(),
        silence: Duration::MAX,
        ..situation.clone()
    }
}

pub fn is_member(situation: &Situation) -> bool {
    situation
        .group
        .find_member(&server(situation.own_name))
        .is_some()
}
