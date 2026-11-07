use std::time::Duration;

use orchestration_core::server_group::ServerStanding;
use orchestration_core::server_keeping::{KeeperAction, ProbeAnswer};
use proptest::prelude::*;

use crate::keeper_situation_support::{
    MOST_SILENCE_SECONDS, Situation, backup_situation, decide, is_member,
    remembered_leader, seconds, silenced,
};
use crate::server_group_support::{join_key, server};

proptest! {
    #[test]
    fn test_decide_backup_action_property_an_active_leader_is_followed(
        situation in backup_situation(),
    ) {
        let KeeperAction::Follow(leader) = decide(&situation) else {
            return Ok(());
        };
        let leader_answer = ProbeAnswer {
            server_id: leader.clone(),
            term: None,
            standing: ServerStanding::Active,
        };
        let mut answered = Situation {
            silence: Duration::MAX,
            ..situation.clone()
        };
        answered.probes.push(leader_answer);

        prop_assert_eq!(decide(&answered), KeeperAction::Follow(leader));
    }

    #[test]
    fn test_decide_backup_action_property_takes_over_one_term_above(
        situation in backup_situation(),
    ) {
        let silent = silenced(&situation);

        let action = decide(&silent);

        let expected = match remembered_leader(&silent) {
            None => KeeperAction::KeepGoing,
            Some(leader) if leader.server_id == server(silent.own_name) => {
                KeeperAction::Resume
            }
            Some(leader) if !is_member(&silent) => {
                KeeperAction::Follow(leader.server_id)
            }
            Some(leader) => KeeperAction::TakeOver {
                number: leader.number + 1,
            },
        };
        prop_assert_eq!(action, expected);
    }

    #[test]
    fn test_decide_backup_action_property_a_stepped_down_leader_is_replaced(
        situation in backup_situation(),
    ) {
        let silent = silenced(&situation);
        let Some(leader) = remembered_leader(&silent) else {
            return Ok(());
        };
        let mut answered_as_backup = silent.clone();
        answered_as_backup.probes.push(ProbeAnswer {
            server_id: leader.server_id,
            term: None,
            standing: ServerStanding::Backup,
        });

        prop_assert_eq!(decide(&answered_as_backup), decide(&silent));
    }

    #[test]
    fn test_has_waited_for_its_turn_property_waits_one_period_per_turn(
        situation in backup_situation(),
    ) {
        let quiet = Situation {
            probes: Vec::new(),
            ..situation
        };
        let Some(leader) = remembered_leader(&quiet) else {
            return Ok(());
        };
        let own_id = server(quiet.own_name);
        let Some(own) = quiet.group.find_member(&own_id) else {
            return Ok(());
        };
        if leader.server_id == own_id {
            return Ok(());
        }
        let mut turn: u32 = 1;
        for member in &quiet.group.members {
            let is_leader = member.membership.server_id == leader.server_id;
            let joined_first = join_key(member) < join_key(own);
            if !is_leader && joined_first {
                turn += 1;
            }
        }

        let action = decide(&quiet);

        if quiet.silence >= quiet.takeover_after * turn {
            let number = leader.number + 1;
            prop_assert_eq!(action, KeeperAction::TakeOver { number });
        } else {
            prop_assert_eq!(action, KeeperAction::Follow(leader.server_id));
        }
    }

    #[test]
    fn test_has_waited_for_its_turn_property_more_silence_keeps_takeover(
        situation in backup_situation(),
        extra in seconds(MOST_SILENCE_SECONDS),
    ) {
        let longer = Situation {
            silence: situation.silence + extra,
            ..situation.clone()
        };

        if matches!(decide(&situation), KeeperAction::TakeOver { .. }) {
            prop_assert_eq!(decide(&longer), decide(&situation));
        }
    }

    #[test]
    fn test_has_waited_for_its_turn_property_a_non_member_never_takes_over(
        situation in backup_situation(),
    ) {
        let mut outsider = silenced(&situation);
        let own_id = server(situation.own_name);
        outsider
            .group
            .members
            .retain(|member| member.membership.server_id != own_id);

        let action = decide(&outsider);

        let is_takeover = matches!(action, KeeperAction::TakeOver { .. });
        prop_assert!(!is_takeover);
    }
}
