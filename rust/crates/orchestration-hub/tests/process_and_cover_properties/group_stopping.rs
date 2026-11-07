use portable_pty::ChildKiller;
use proptest::prelude::*;

use crate::group_support::{
    StartedLeader, ensure_no_survivors, script_with_members, start_leader,
};
use crate::process_support::CaseOutcome;
use crate::target_folders::fail_with;

const LEAVE_A_MEMBER_AND_EXIT: &str =
    "sleep 30 </dev/null >/dev/null 2>&1 & echo $!; exit 0";
pub const ENDED_GROUP_SCRIPT: &str = "echo done; exit 3";
pub const ENDED_GROUP_CODE: u32 = 3;

pub type StopGroup = fn(&mut StartedLeader) -> CaseOutcome;

pub fn kill_with_leader(started: &mut StartedLeader) -> CaseOutcome {
    started.leader.kill().map_err(|problem| fail_with(&problem))
}

pub fn kill_with_copy(started: &mut StartedLeader) -> CaseOutcome {
    let mut killer = started.leader.clone_killer();
    killer.kill().map_err(|problem| fail_with(&problem))
}

pub fn kill_with_copy_of_copies(
    started: &mut StartedLeader,
    depth: usize,
) -> CaseOutcome {
    let mut killer = started.leader.clone_killer();
    for _ in 0..depth {
        killer = killer.clone_killer();
    }
    killer.kill().map_err(|problem| fail_with(&problem))
}

pub fn ends_every_member(
    member_count: usize,
    member_setup: &str,
    stop: StopGroup,
) -> CaseOutcome {
    let mut started =
        start_leader(&script_with_members(member_count, member_setup))?;
    let member_ids = started.read_until_ready()?;

    stop(&mut started)?;
    let status = started.wait()?;

    prop_assert!(!status.success());
    ensure_no_survivors(&member_ids)
}

pub fn harmless_after_the_group_ended(
    kill_count: usize,
    stop: StopGroup,
) -> CaseOutcome {
    let mut started = start_leader(ENDED_GROUP_SCRIPT)?;
    started.wait_for_output_end()?;

    for _ in 0..kill_count {
        stop(&mut started)?;
    }
    let status = started.wait()?;

    prop_assert_eq!(status.exit_code(), ENDED_GROUP_CODE);
    Ok(())
}

pub fn ends_a_member_left_by_an_exited_leader(stop: StopGroup) -> CaseOutcome {
    let mut started = start_leader(LEAVE_A_MEMBER_AND_EXIT)?;
    let member_id = started.read_line()?;
    started.wait_for_output_end()?;

    stop(&mut started)?;
    started.wait()?;

    ensure_no_survivors(&[member_id])
}
