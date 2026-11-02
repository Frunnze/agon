use std::time::Duration;

use chrono::{DateTime, TimeDelta, Utc};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::peer_address::{
    ENDPOINT_PUBLIC_KEY_LENGTH, PeerAddress,
};
use orchestration_core::server_group::{
    AuditSigners, ServerGroup, ServerMember, ServerMembership, ServerStanding,
    ServerTerm,
};
use orchestration_core::server_keeping::{
    KeeperAction, KeeperObservation, ProbeAnswer, decide_keeper_action,
};
use proptest::collection::vec;
use proptest::prelude::*;

const SERVER_NAMES: [&str; 4] = ["a", "b", "c", "d"];
const MOST_TERM_NUMBER: u64 = 6;
const MOST_SILENCE_SECONDS: u64 = 200;
const TAKEOVER_SECONDS: u64 = 30;

fn server(name: &str) -> DeviceId {
    DeviceId(name.to_owned())
}

fn term(number: u64, server_name: &str) -> ServerTerm {
    ServerTerm {
        number,
        server_id: server(server_name),
        claimed_by: server(server_name),
        signature: Vec::new(),
    }
}

fn group_with_term(active_term: ServerTerm) -> ServerGroup {
    let mut members = Vec::new();
    for (offset, name) in (0_i64..).zip(SERVER_NAMES) {
        let endpoint_public_key = [0; ENDPOINT_PUBLIC_KEY_LENGTH];
        members.push(ServerMember {
            membership: ServerMembership {
                device_id: server(name),
                server_id: server(name),
                server_signing_public_key: Vec::new(),
                endpoint_public_key,
                joined_at: DateTime::<Utc>::UNIX_EPOCH
                    + TimeDelta::seconds(offset),
                signature: Vec::new(),
            },
            address: PeerAddress {
                endpoint_public_key,
                direct_addresses: Vec::new(),
                relay_url: None,
            },
        });
    }
    ServerGroup {
        term: Some(active_term),
        members,
        audit_signers: AuditSigners::new(),
    }
}

fn standing_strategy() -> impl Strategy<Value = ServerStanding> {
    prop_oneof![Just(ServerStanding::Active), Just(ServerStanding::Backup)]
}

fn probe_strategy() -> impl Strategy<Value = ProbeAnswer> {
    (
        prop::sample::select(SERVER_NAMES.to_vec()),
        proptest::option::of((
            0..MOST_TERM_NUMBER,
            prop::sample::select(SERVER_NAMES.to_vec()),
        )),
        standing_strategy(),
    )
        .prop_map(|(name, chosen_term, standing)| ProbeAnswer {
            server_id: server(name),
            term: chosen_term.map(|(number, owner)| term(number, owner)),
            standing,
        })
}

fn observe(
    group: &ServerGroup,
    own_name: &str,
    standing: ServerStanding,
    probes: &[ProbeAnswer],
    silence_seconds: u64,
) -> KeeperAction {
    observe_knowing(group, own_name, standing, None, probes, silence_seconds)
}

fn observe_knowing(
    group: &ServerGroup,
    own_name: &str,
    standing: ServerStanding,
    known_term: Option<&ServerTerm>,
    probes: &[ProbeAnswer],
    silence_seconds: u64,
) -> KeeperAction {
    let own_server_id = server(own_name);
    decide_keeper_action(&KeeperObservation {
        group,
        own_server_id: &own_server_id,
        standing,
        known_term,
        probes,
        silence: Duration::from_secs(silence_seconds),
        takeover_after: Duration::from_secs(TAKEOVER_SECONDS),
    })
}

proptest! {
    #[test]
    fn test_decide_keeper_action_property_a_higher_term_always_wins(
        own_number in 1..MOST_TERM_NUMBER,
        own_owner in prop::sample::select(SERVER_NAMES.to_vec()),
        own_name in prop::sample::select(SERVER_NAMES.to_vec()),
        standing in standing_strategy(),
        probes in vec(probe_strategy(), 0..6),
        silence_seconds in 0..MOST_SILENCE_SECONDS,
    ) {
        let own_term = term(own_number, own_owner);
        let group = group_with_term(own_term.clone());
        let highest = probes
            .iter()
            .filter_map(|probe| probe.term.as_ref())
            .filter(|seen| seen.outranks(&own_term))
            .filter(|seen| seen.server_id != server(own_name))
            .max_by_key(|seen| (seen.number, seen.server_id.clone()))
            .cloned();

        let action =
            observe(&group, own_name, standing, &probes, silence_seconds);

        match (highest, standing) {
            (Some(seen), ServerStanding::Active) => {
                let steps_down = KeeperAction::StepDown(seen.server_id);
                prop_assert_eq!(action, steps_down);
            }
            (Some(seen), ServerStanding::Backup) => {
                let above = KeeperAction::TakeOver { number: seen.number + 1 };
                let follows = KeeperAction::Follow(seen.server_id);
                prop_assert!(action == follows || action == above);
            }
            (None, ServerStanding::Active) if own_owner == own_name => {
                prop_assert_eq!(action, KeeperAction::KeepGoing);
            }
            (None, ServerStanding::Active) => {
                let steps_down = KeeperAction::StepDown(server(own_owner));
                prop_assert_eq!(action, steps_down);
            }
            (None, ServerStanding::Backup) => {
                prop_assert!(!matches!(action, KeeperAction::StepDown(_)));
                prop_assert_ne!(action, KeeperAction::KeepGoing);
            }
        }
    }

    #[test]
    fn test_decide_keeper_action_property_takes_over_only_after_its_turn(
        own_index in 1..SERVER_NAMES.len(),
        silence_seconds in 0..MOST_SILENCE_SECONDS,
    ) {
        let group = group_with_term(term(1, SERVER_NAMES[0]));
        let own_name = SERVER_NAMES[own_index];
        let position = u64::try_from(own_index)?;

        let action = observe(
            &group,
            own_name,
            ServerStanding::Backup,
            &[],
            silence_seconds,
        );

        if silence_seconds >= TAKEOVER_SECONDS * position {
            prop_assert_eq!(action, KeeperAction::TakeOver { number: 2 });
        } else {
            prop_assert_eq!(
                action,
                KeeperAction::Follow(server(SERVER_NAMES[0]))
            );
        }
    }

    #[test]
    fn test_decide_keeper_action_property_follows_an_active_term_server(
        own_index in 1..SERVER_NAMES.len(),
        silence_seconds in 0..MOST_SILENCE_SECONDS,
    ) {
        let active_term = term(3, SERVER_NAMES[0]);
        let group = group_with_term(active_term.clone());
        let probes = [ProbeAnswer {
            server_id: server(SERVER_NAMES[0]),
            term: Some(active_term),
            standing: ServerStanding::Active,
        }];

        let action = observe(
            &group,
            SERVER_NAMES[own_index],
            ServerStanding::Backup,
            &probes,
            silence_seconds,
        );

        prop_assert_eq!(
            action,
            KeeperAction::Follow(server(SERVER_NAMES[0]))
        );
    }
}

#[test]
fn test_decide_keeper_action_property_a_restarted_term_server_resumes() {
    let group = group_with_term(term(2, "a"));
    let lower_probe = ProbeAnswer {
        server_id: server("b"),
        term: Some(term(1, "b")),
        standing: ServerStanding::Active,
    };

    let alone = observe(&group, "a", ServerStanding::Backup, &[], 0);
    let with_lower =
        observe(&group, "a", ServerStanding::Backup, &[lower_probe], 0);

    assert_eq!(alone, KeeperAction::Resume);
    assert_eq!(with_lower, KeeperAction::Resume);
}

#[test]
fn test_decide_keeper_action_property_a_non_member_never_takes_over() {
    let group = group_with_term(term(1, "a"));

    let action =
        observe(&group, "stranger", ServerStanding::Backup, &[], u64::MAX);

    assert_eq!(action, KeeperAction::Follow(server("a")));
}

#[test]
fn test_decide_keeper_action_property_a_known_higher_term_blocks_resuming() {
    let group = group_with_term(term(2, "a"));
    let known = term(3, "b");

    let action = observe_knowing(
        &group,
        "a",
        ServerStanding::Backup,
        Some(&known),
        &[],
        0,
    );
    let after_waiting = observe_knowing(
        &group,
        "a",
        ServerStanding::Backup,
        Some(&known),
        &[],
        TAKEOVER_SECONDS,
    );

    assert_eq!(action, KeeperAction::Follow(server("b")));
    assert_eq!(after_waiting, KeeperAction::TakeOver { number: 4 });
}

#[test]
fn test_decide_keeper_action_property_an_active_steps_down_to_a_known_term() {
    let group = group_with_term(term(1, "a"));
    let known = term(2, "b");

    let action = observe_knowing(
        &group,
        "a",
        ServerStanding::Active,
        Some(&known),
        &[],
        0,
    );

    assert_eq!(action, KeeperAction::StepDown(server("b")));
}
