use std::thread;
use std::time::Duration;

use orchestration_hub::piped_process::PipedProcess;
use orchestration_hub::process_supervisor::RunningProcess;
use proptest::prelude::*;

use crate::group_support::READY_LINE;
use crate::process_support::{
    CaseOutcome, finish_within_time_limit, list_survivors, read_every_line,
    read_next_line, read_process_group, run_piped_to_end, shell_command,
    start_piped,
};
use crate::target_folders::fail_with;

const PROCESS_CASES: u32 = 6;
const PRINT_OWN_GROUP: &str = "echo $$; ps -o pgid= -p $$";
const PRINT_MEMBER_GROUP: &str = "sleep 1 & echo $$; ps -o pgid= -p $!; wait";
const LEAVE_MEMBERS_AND_EXIT: &str =
    "sleep 30 </dev/null >/dev/null 2>&1 & echo $!; exit 0";
const NESTED_MEMBERS: &str =
    "(sleep 30 & echo $!; sleep 30 & echo $!; wait) & echo ready; wait";
const IGNORING_MEMBERS: &str =
    "trap '' HUP; sleep 30 & echo $!; echo ready; wait";
const EXIT_SETTLING_TIME: Duration = Duration::from_millis(300);

fn read_members_until_ready(
    process: &mut RunningProcess,
) -> Result<Vec<String>, TestCaseError> {
    let mut member_ids = Vec::new();
    loop {
        let line = read_next_line(process)?;
        if line == READY_LINE {
            return Ok(member_ids);
        }
        member_ids.push(line);
    }
}

fn stop_and_list_survivors(
    script: &str,
) -> Result<Vec<String>, TestCaseError> {
    let PipedProcess {
        mut process,
        input_lines,
    } = start_piped(&shell_command(script, &[]))?;
    let member_ids = read_members_until_ready(&mut process)?;

    process.stop().map_err(|problem| fail_with(&problem))?;
    process
        .wait_for_exit()
        .map_err(|problem| fail_with(&problem))?;
    drop(input_lines);

    list_survivors(&member_ids)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PROCESS_CASES))]

    #[test]
    fn test_start_in_own_process_group_property_leads_its_own_group(
        _attempt in 0_u8..3,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let (lines, _exit) =
                run_piped_to_end(&shell_command(PRINT_OWN_GROUP, &[]))?;

            prop_assert_eq!(lines.len(), 2);
            prop_assert_eq!(lines[1].trim(), lines[0].trim());
            Ok(())
        })?;
    }

    #[test]
    fn test_start_in_own_process_group_property_differs_from_the_hub_group(
        _attempt in 0_u8..3,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let hub_process_id = std::process::id().to_string();
            let hub_group = read_process_group(&hub_process_id)?;

            let (lines, _exit) =
                run_piped_to_end(&shell_command(PRINT_OWN_GROUP, &[]))?;

            prop_assert_ne!(lines[1].trim(), hub_group);
            Ok(())
        })?;
    }

    #[test]
    fn test_start_in_own_process_group_property_children_join_the_group(
        _attempt in 0_u8..3,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let (lines, _exit) =
                run_piped_to_end(&shell_command(PRINT_MEMBER_GROUP, &[]))?;

            prop_assert_eq!(lines.len(), 2);
            prop_assert_eq!(lines[1].trim(), lines[0].trim());
            Ok(())
        })?;
    }

    #[test]
    fn test_supervise_with_its_children_property_stop_ends_nested_children(
        _attempt in 0_u8..3,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let survivors = stop_and_list_survivors(NESTED_MEMBERS)?;

            prop_assert!(survivors.is_empty(), "still running: {survivors:?}");
            Ok(())
        })?;
    }

    #[test]
    fn test_supervise_with_its_children_property_stop_ends_ignoring_children(
        _attempt in 0_u8..3,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let survivors = stop_and_list_survivors(IGNORING_MEMBERS)?;

            prop_assert!(survivors.is_empty(), "still running: {survivors:?}");
            Ok(())
        })?;
    }

    #[test]
    fn test_supervise_with_its_children_property_stop_ends_leftover_children(
        _attempt in 0_u8..3,
    ) {
        finish_within_time_limit(move || -> CaseOutcome {
            let PipedProcess { mut process, input_lines } =
                start_piped(&shell_command(LEAVE_MEMBERS_AND_EXIT, &[]))?;
            let member_id = read_next_line(&mut process)?;
            read_every_line(&mut process);
            thread::sleep(EXIT_SETTLING_TIME);

            process.stop().map_err(|problem| fail_with(&problem))?;
            process.wait_for_exit().map_err(|problem| fail_with(&problem))?;
            drop(input_lines);

            let survivors = list_survivors(&[member_id])?;
            prop_assert!(survivors.is_empty(), "still running: {survivors:?}");
            Ok(())
        })?;
    }
}
