use std::time::{Duration, Instant};

use portable_pty::ChildKiller;
use proptest::prelude::*;

use crate::group_stopping::{
    ends_a_member_left_by_an_exited_leader, harmless_after_the_group_ended,
    kill_with_copy, kill_with_leader,
};
use crate::group_support::{
    ensure_no_survivors, script_with_members, start_leader,
};
use crate::process_support::{CaseOutcome, finish_within_time_limit};

const GROUP_CASES: u32 = 3;
const IGNORE_HANG_UP: &str = "trap '' HUP; ";
const ANSWER_HANG_UP: &str =
    "trap 'echo hung up; exit 7' HUP; sleep 30 & echo ready; wait";
const HANG_UP_ANSWER: &str = "hung up";
const HANDLED_HANG_UP_CODE: u32 = 7;
const KILL_SIGNAL_NUMBER_TEXT: &str = "9";
const STOP_TIME_LIMIT: Duration = Duration::from_secs(3);
const LARGEST_MEMBER_COUNT: usize = 3;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GROUP_CASES))]

    #[test]
    fn test_stop_process_group_property_hangs_up_before_killing(
        _attempt in 0_u8..2,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut started = start_leader(ANSWER_HANG_UP)?;
            started.read_until_ready()?;

            kill_with_leader(&mut started)?;
            let answer = started.read_line()?;
            let status = started.wait()?;

            prop_assert_eq!(answer, HANG_UP_ANSWER);
            prop_assert_eq!(status.exit_code(), HANDLED_HANG_UP_CODE);
            prop_assert_eq!(status.signal(), None);
            Ok(())
        })?;
    }

    #[test]
    fn test_stop_process_group_property_forces_out_ignored_hang_ups(
        _attempt in 0_u8..2,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let script = format!("{IGNORE_HANG_UP}echo ready; sleep 30");
            let mut started = start_leader(&script)?;
            started.read_until_ready()?;

            kill_with_leader(&mut started)?;
            let status = started.wait()?;

            let signal = status.signal().unwrap_or_default().to_owned();
            prop_assert!(signal.contains(KILL_SIGNAL_NUMBER_TEXT), "{signal}");
            Ok(())
        })?;
    }

    #[test]
    fn test_stop_process_group_property_returns_soon_after_the_grace_period(
        member_setup in prop_oneof![Just(""), Just(IGNORE_HANG_UP)],
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut started =
                start_leader(&script_with_members(2, member_setup))?;
            let member_ids = started.read_until_ready()?;

            let stop_requested_at = Instant::now();
            kill_with_leader(&mut started)?;
            let stop_duration = stop_requested_at.elapsed();
            started.wait()?;

            prop_assert!(stop_duration < STOP_TIME_LIMIT, "{stop_duration:?}");
            ensure_no_survivors(&member_ids)
        })?;
    }

    #[test]
    fn test_send_to_group_property_exited_members_are_not_an_error(
        kill_count in 1_usize..3,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            harmless_after_the_group_ended(kill_count, kill_with_leader)
        })?;
    }

    #[test]
    fn test_send_to_group_property_reaches_nested_subshells(
        member_count in 1..=LARGEST_MEMBER_COUNT,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let nested = script_with_members(member_count, "");
            let script = format!("( {nested} ) & wait");
            let mut started = start_leader(&script)?;
            let member_ids = started.read_until_ready()?;

            kill_with_leader(&mut started)?;
            started.wait()?;

            ensure_no_survivors(&member_ids)
        })?;
    }

    #[test]
    fn test_send_to_group_property_reaches_members_of_an_exited_leader(
        _attempt in 0_u8..2,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            ends_a_member_left_by_an_exited_leader(kill_with_leader)
        })?;
    }

    #[test]
    fn test_is_group_already_gone_property_ended_group_counts_as_gone(
        code in 0_u32..256,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut started = start_leader(&format!("exit {code}"))?;
            started.wait_for_output_end()?;

            let killed = started.leader.kill();
            let status = started.wait()?;

            prop_assert!(killed.is_ok(), "{killed:?}");
            prop_assert_eq!(status.exit_code(), code);
            Ok(())
        })?;
    }

    #[test]
    fn test_is_group_already_gone_property_living_member_is_not_gone(
        _attempt in 0_u8..2,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            ends_a_member_left_by_an_exited_leader(kill_with_leader)
        })?;
    }

    #[test]
    fn test_is_group_already_gone_property_copies_agree_on_an_ended_group(
        kill_count in 1_usize..3,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            harmless_after_the_group_ended(kill_count, kill_with_copy)
        })?;
    }
}
