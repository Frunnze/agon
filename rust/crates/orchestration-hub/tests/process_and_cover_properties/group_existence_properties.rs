use std::process::{Command, Stdio};

use orchestration_hub::process_group::ProcessGroupLeader;
use portable_pty::{Child, ChildKiller};
use proptest::prelude::*;

use crate::group_support::{script_with_members, spawn_in_own_group};
use crate::process_support::{CaseOutcome, finish_within_time_limit};
use crate::target_folders::fail_with;

const GROUP_CASES: u32 = 3;
const READ_INPUT_PROGRAM: &str = "/bin/cat";
const LARGEST_PROCESS_COUNT: usize = 3;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GROUP_CASES))]

    #[test]
    fn test_ensure_group_exists_property_refuses_every_shared_group_process(
        process_count in 1..=LARGEST_PROCESS_COUNT,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            for _ in 0..process_count {
                let process = Command::new(READ_INPUT_PROGRAM)
                    .stdin(Stdio::piped())
                    .stdout(Stdio::null())
                    .spawn()
                    .map_err(|problem| fail_with(&problem))?;

                let leader = ProcessGroupLeader::new(process);

                let Err(problem) = leader else {
                    return Err(TestCaseError::fail("a non-leader was taken"));
                };
                prop_assert!(!problem.to_string().is_empty());
            }
            Ok(())
        })?;
    }

    #[test]
    fn test_ensure_group_exists_property_accepts_a_leader_with_members(
        member_count in 0..=LARGEST_PROCESS_COUNT,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let script = script_with_members(member_count, "");
            let process = spawn_in_own_group(&script)?;

            let mut leader = ProcessGroupLeader::new(process)
                .map_err(|problem| fail_with(&problem))?;

            leader.kill().map_err(|problem| fail_with(&problem))?;
            leader.wait().map_err(|problem| fail_with(&problem))?;
            Ok(())
        })?;
    }

    #[test]
    fn test_ensure_group_exists_property_refuses_a_leader_already_reaped(
        code in 0_u32..256,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let mut process = spawn_in_own_group(&format!("exit {code}"))?;
            let finished = process
                .wait()
                .map_err(|problem| fail_with(&problem))?
                .code();
            let leader = ProcessGroupLeader::new(process);

            prop_assert_eq!(finished, i32::try_from(code).ok());
            prop_assert!(leader.is_err());
            Ok(())
        })?;
    }
}
