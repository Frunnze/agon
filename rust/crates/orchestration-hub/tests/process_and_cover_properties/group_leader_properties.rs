use std::process::{Command, Stdio};

use orchestration_hub::process_group::ProcessGroupLeader;
use portable_pty::{Child, ChildKiller};
use proptest::prelude::*;

use crate::group_support::{
    StartedLeader, describe_status, ensure_no_survivors, script_with_members,
    spawn_in_own_group, start_leader, wait_until_finished,
};
use crate::process_support::{
    CaseOutcome, finish_within_time_limit, read_process_group,
};
use crate::target_folders::fail_with;

const GROUP_CASES: u32 = 3;
const READ_INPUT_PROGRAM: &str = "/bin/cat";
const WAIT_AFTER_READY: &str = "echo ready; sleep 30";

fn start_and_stop(started: &mut StartedLeader) -> CaseOutcome {
    started.read_until_ready()?;
    started
        .leader
        .kill()
        .map_err(|problem| fail_with(&problem))?;
    started.wait()?;
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GROUP_CASES))]

    #[test]
    fn test_process_group_leader_new_property_keeps_the_process_id(
        code in 0_u8..8,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut started = start_leader(&format!("exit {code}"))?;

            let process_id = started.leader.process_id();
            started.wait()?;

            prop_assert_eq!(process_id, Some(started.started_process_id));
            Ok(())
        })?;
    }

    #[test]
    fn test_process_group_leader_new_property_refuses_a_non_leader(
        _attempt in 0_u8..2,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let process = Command::new(READ_INPUT_PROGRAM)
                .stdin(Stdio::piped())
                .stdout(Stdio::null())
                .spawn()
                .map_err(|problem| fail_with(&problem))?;

            let leader = ProcessGroupLeader::new(process);

            prop_assert!(leader.is_err());
            Ok(())
        })?;
    }

    #[test]
    fn test_process_group_leader_new_property_accepts_a_leader_that_exited(
        code in 0_u32..256,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut started = start_leader(&format!("exit {code}"))?;
            started.wait_for_output_end()?;

            let status = started.wait()?;

            prop_assert_eq!(status.exit_code(), code);
            Ok(())
        })?;
    }

    #[test]
    fn test_try_wait_property_reports_nothing_while_running(
        _attempt in 0_u8..2,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut started = start_leader(WAIT_AFTER_READY)?;
            started.read_until_ready()?;

            let status = started.leader.try_wait();

            started.leader.kill().map_err(|problem| fail_with(&problem))?;
            started.wait()?;
            prop_assert!(matches!(status, Ok(None)), "{status:?}");
            Ok(())
        })?;
    }

    #[test]
    fn test_try_wait_property_reports_the_exit_once_finished(
        code in 0_u32..256,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut started = start_leader(&format!("exit {code}"))?;

            let status = wait_until_finished(&mut started)?;

            prop_assert_eq!(status.exit_code(), code);
            prop_assert_eq!(status.success(), code == 0);
            prop_assert_eq!(status.signal(), None);
            Ok(())
        })?;
    }

    #[test]
    fn test_try_wait_property_repeats_the_same_exit(
        code in 0_u32..256,
        repeat_count in 1_usize..4,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut started = start_leader(&format!("exit {code}"))?;
            let first_status = wait_until_finished(&mut started)?;

            for _ in 0..repeat_count {
                let status = started
                    .leader
                    .try_wait()
                    .map_err(|problem| fail_with(&problem))?;
                let described = status.as_ref().map(describe_status);
                let expected = describe_status(&first_status);
                prop_assert_eq!(described, Some(expected));
            }
            Ok(())
        })?;
    }

    #[test]
    fn test_wait_property_reports_every_exit_code(code in 0_u32..256) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut started = start_leader(&format!("exit {code}"))?;

            let status = started.wait()?;

            prop_assert_eq!(status.exit_code(), code);
            prop_assert_eq!(status.success(), code == 0);
            Ok(())
        })?;
    }

    #[test]
    fn test_wait_property_reports_the_signal_of_a_stopped_group(
        _attempt in 0_u8..2,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut started = start_leader(WAIT_AFTER_READY)?;
            started.read_until_ready()?;
            started.leader.kill().map_err(|problem| fail_with(&problem))?;

            let status = started.wait()?;

            prop_assert!(status.signal().is_some(), "{status:?}");
            prop_assert!(!status.success());
            Ok(())
        })?;
    }

    #[test]
    fn test_wait_property_agrees_with_try_wait(code in 0_u32..256) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut started = start_leader(&format!("exit {code}"))?;
            let polled_status = wait_until_finished(&mut started)?;

            let waited_status = started.wait()?;

            prop_assert_eq!(
                describe_status(&waited_status),
                describe_status(&polled_status)
            );
            Ok(())
        })?;
    }

    #[test]
    fn test_process_id_property_matches_the_started_process(
        member_count in 0_usize..3,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let script = script_with_members(member_count, "");
            let mut started = start_leader(&script)?;
            let process_id = started.leader.process_id();

            let member_ids = started.read_until_ready()?;
            started.leader.kill().map_err(|problem| fail_with(&problem))?;
            started.wait()?;

            prop_assert_eq!(process_id, Some(started.started_process_id));
            ensure_no_survivors(&member_ids)?;
            Ok(())
        })?;
    }

    #[test]
    fn test_process_id_property_stays_the_same_after_exit(code in 0_u8..8) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut started = start_leader(&format!("exit {code}"))?;
            let process_id_while_new = started.leader.process_id();

            started.wait()?;

            prop_assert_eq!(started.leader.process_id(), process_id_while_new);
            Ok(())
        })?;
    }

    #[test]
    fn test_process_id_property_names_the_group_it_leads(
        _attempt in 0_u8..2,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut started = start_leader(WAIT_AFTER_READY)?;
            let group = read_process_group(&started.process_id_text())?;

            start_and_stop(&mut started)?;

            prop_assert_eq!(group, started.process_id_text());
            Ok(())
        })?;
    }

    #[test]
    fn test_find_group_property_members_share_the_leader_group(
        member_count in 1_usize..3,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let script = script_with_members(member_count, "");
            let mut started = start_leader(&script)?;
            let member_ids = started.read_until_ready()?;

            let mut member_groups = Vec::new();
            for member_id in &member_ids {
                member_groups.push(read_process_group(member_id)?);
            }
            started.leader.kill().map_err(|problem| fail_with(&problem))?;
            started.wait()?;

            let leader_id = started.process_id_text();
            for member_group in &member_groups {
                prop_assert_eq!(member_group, &leader_id);
            }
            ensure_no_survivors(&member_ids)?;
            Ok(())
        })?;
    }

    #[test]
    fn test_find_group_property_separate_leaders_stay_apart(
        _attempt in 0_u8..2,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut stopped = start_leader(WAIT_AFTER_READY)?;
            let mut kept = start_leader(WAIT_AFTER_READY)?;
            kept.read_until_ready()?;
            start_and_stop(&mut stopped)?;

            let kept_status = kept.leader.try_wait();

            kept.leader.kill().map_err(|problem| fail_with(&problem))?;
            kept.wait()?;
            prop_assert!(matches!(kept_status, Ok(None)), "{kept_status:?}");
            Ok(())
        })?;
    }

    #[test]
    fn test_find_group_property_group_is_the_spawned_process(
        _attempt in 0_u8..2,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let process = spawn_in_own_group(WAIT_AFTER_READY)?;
            let process_id = process.id().to_string();
            let group = read_process_group(&process_id)?;
            let mut leader = ProcessGroupLeader::new(process)
                .map_err(|problem| fail_with(&problem))?;

            leader.kill().map_err(|problem| fail_with(&problem))?;
            leader.wait().map_err(|problem| fail_with(&problem))?;

            prop_assert_eq!(group, process_id);
            Ok(())
        })?;
    }
}
