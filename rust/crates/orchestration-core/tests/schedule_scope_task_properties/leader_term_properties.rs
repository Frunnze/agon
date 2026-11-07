use orchestration_core::server_group::ServerStanding;
use orchestration_core::server_keeping::{KeeperAction, ProbeAnswer};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::keeper_situation_support::{
    MOST_PROBES, Situation, decide, remembered_leader, situation, standing,
};
use crate::server_group_support::{MOST_TERM_NUMBER, server, term};

const MOST_OWN_TERM_NUMBER: u64 = MOST_TERM_NUMBER * 2;

proptest! {
    #[test]
    fn test_choose_highest_property_an_active_serves_the_higher_term(
        situation in situation(),
    ) {
        let active = Situation {
            standing: ServerStanding::Active,
            probes: Vec::new(),
            ..situation
        };

        let action = decide(&active);

        let expected = match remembered_leader(&active) {
            None => KeeperAction::KeepGoing,
            Some(leader) if leader.server_id == server(active.own_name) => {
                KeeperAction::KeepGoing
            }
            Some(leader) => KeeperAction::StepDown(leader.server_id),
        };
        prop_assert_eq!(action, expected);
    }

    #[test]
    fn test_choose_highest_property_group_and_known_terms_are_symmetric(
        situation in situation(),
    ) {
        let mut swapped = situation.clone();
        swapped.group.term = situation.known_term.clone();
        swapped.known_term = situation.group.term.clone();

        prop_assert_eq!(decide(&swapped), decide(&situation));
    }

    #[test]
    fn test_choose_highest_property_knowing_the_group_term_changes_nothing(
        situation in situation(),
    ) {
        let unknown = Situation {
            known_term: None,
            ..situation.clone()
        };
        let known_again = Situation {
            known_term: situation.group.term.clone(),
            ..situation
        };

        prop_assert_eq!(decide(&known_again), decide(&unknown));
    }

    #[test]
    fn test_find_higher_term_property_ignores_terms_naming_itself(
        situation in situation(),
        numbers in vec(0..MOST_OWN_TERM_NUMBER, 0..MOST_PROBES),
        standings in vec(standing(), MOST_PROBES),
    ) {
        let mut with_own_terms = situation.clone();
        for (number, standing) in numbers.into_iter().zip(standings) {
            with_own_terms.probes.push(ProbeAnswer {
                server_id: server(situation.own_name),
                term: Some(term(number, situation.own_name)),
                standing,
            });
        }

        prop_assert_eq!(decide(&with_own_terms), decide(&situation));
    }

    #[test]
    fn test_find_higher_term_property_ignores_terms_that_do_not_outrank(
        situation in situation(),
    ) {
        let remembered = remembered_leader(&situation);
        let mut lowered = situation.clone();
        for probe in &mut lowered.probes {
            let outranks = probe.term.as_ref().is_some_and(|seen| {
                remembered.as_ref().is_none_or(|own| seen.outranks(own))
            });
            if !outranks {
                probe.term = None;
            }
        }

        prop_assert_eq!(decide(&lowered), decide(&situation));
    }

    #[test]
    fn test_find_higher_term_property_ignores_the_probe_order(
        situation in situation(),
    ) {
        let mut reversed = situation.clone();
        reversed.probes.reverse();

        prop_assert_eq!(decide(&reversed), decide(&situation));
    }
}
