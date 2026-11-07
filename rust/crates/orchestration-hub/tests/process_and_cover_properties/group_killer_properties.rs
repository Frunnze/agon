use portable_pty::ChildKiller;
use proptest::prelude::*;

use crate::group_stopping::{
    ENDED_GROUP_CODE, ENDED_GROUP_SCRIPT,
    ends_a_member_left_by_an_exited_leader, ends_every_member,
    harmless_after_the_group_ended, kill_with_copy, kill_with_copy_of_copies,
    kill_with_leader,
};
use crate::group_support::{
    ensure_no_survivors, script_with_members, start_leader,
};
use crate::process_support::{CaseOutcome, finish_within_time_limit};
use crate::target_folders::fail_with;

const GROUP_CASES: u32 = 3;
const IGNORE_HANG_UP: &str = "trap '' HUP; ";
const LARGEST_MEMBER_COUNT: usize = 3;
const LARGEST_COPY_DEPTH: usize = 4;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GROUP_CASES))]

    #[test]
    fn test_process_group_leader_kill_property_ends_every_member(
        member_count in 1..=LARGEST_MEMBER_COUNT,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            ends_every_member(member_count, "", kill_with_leader)
        })?;
    }

    #[test]
    fn test_process_group_leader_kill_property_harmless_after_the_end(
        kill_count in 1_usize..3,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            harmless_after_the_group_ended(kill_count, kill_with_leader)
        })?;
    }

    #[test]
    fn test_process_group_leader_kill_property_ends_members_ignoring_hang_up(
        member_count in 1..=LARGEST_MEMBER_COUNT,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            ends_every_member(member_count, IGNORE_HANG_UP, kill_with_leader)
        })?;
    }

    #[test]
    fn test_process_group_leader_clone_killer_property_copy_ends_the_group(
        member_count in 1..=LARGEST_MEMBER_COUNT,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            ends_every_member(member_count, "", kill_with_copy)
        })?;
    }

    #[test]
    fn test_process_group_leader_clone_killer_property_copies_agree(
        copy_count in 1_usize..4,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut started = start_leader(&script_with_members(1, ""))?;
            let member_ids = started.read_until_ready()?;

            let mut killers = Vec::new();
            for _ in 0..copy_count {
                killers.push(started.leader.clone_killer());
            }
            for killer in &mut killers {
                killer.kill().map_err(|problem| fail_with(&problem))?;
            }
            started.wait()?;

            ensure_no_survivors(&member_ids)
        })?;
    }

    #[test]
    fn test_process_group_leader_clone_killer_property_copy_harmless_after_end(
        kill_count in 1_usize..3,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            harmless_after_the_group_ended(kill_count, kill_with_copy)
        })?;
    }

    #[test]
    fn test_process_group_killer_kill_property_ends_every_member(
        member_count in 1..=LARGEST_MEMBER_COUNT,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            ends_every_member(member_count, "", kill_with_copy)
        })?;
    }

    #[test]
    fn test_process_group_killer_kill_property_ends_members_ignoring_hang_up(
        member_count in 1..=LARGEST_MEMBER_COUNT,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            ends_every_member(member_count, IGNORE_HANG_UP, kill_with_copy)
        })?;
    }

    #[test]
    fn test_process_group_killer_kill_property_ends_members_of_exited_leader(
        _attempt in 0_u8..2,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            ends_a_member_left_by_an_exited_leader(kill_with_copy)
        })?;
    }

    #[test]
    fn test_process_group_killer_clone_killer_property_copies_end_the_group(
        depth in 1..=LARGEST_COPY_DEPTH,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut started = start_leader(&script_with_members(2, ""))?;
            let member_ids = started.read_until_ready()?;

            kill_with_copy_of_copies(&mut started, depth)?;
            started.wait()?;

            ensure_no_survivors(&member_ids)
        })?;
    }

    #[test]
    fn test_process_group_killer_clone_killer_property_outlives_the_original(
        depth in 1..=LARGEST_COPY_DEPTH,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut started = start_leader(&script_with_members(1, ""))?;
            let member_ids = started.read_until_ready()?;
            let original = started.leader.clone_killer();
            let mut copy = original.clone_killer();
            drop(original);
            for _ in 1..depth {
                copy = copy.clone_killer();
            }

            copy.kill().map_err(|problem| fail_with(&problem))?;
            started.wait()?;

            ensure_no_survivors(&member_ids)
        })?;
    }

    #[test]
    fn test_process_group_killer_clone_killer_property_harmless_after_end(
        depth in 1..=LARGEST_COPY_DEPTH,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut started = start_leader(ENDED_GROUP_SCRIPT)?;
            started.wait_for_output_end()?;

            kill_with_copy_of_copies(&mut started, depth)?;
            let status = started.wait()?;

            prop_assert_eq!(status.exit_code(), ENDED_GROUP_CODE);
            Ok(())
        })?;
    }
}
