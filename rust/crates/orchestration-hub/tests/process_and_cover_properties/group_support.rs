use std::io::{BufRead, BufReader, Lines};
use std::os::unix::process::CommandExt;
use std::process::{Child as StartedProcess, ChildStdout, Command, Stdio};
use std::thread;
use std::time::Duration;

use orchestration_hub::process_group::ProcessGroupLeader;
use portable_pty::{Child, ExitStatus};
use proptest::test_runner::TestCaseError;

use crate::process_support::{SHELL, list_survivors};
use crate::target_folders::fail_with;

pub type DescribedStatus = (u32, bool, Option<String>);

pub const READY_LINE: &str = "ready";
const SCRIPT_OPTION: &str = "-c";
const EXIT_SETTLING_TIME: Duration = Duration::from_millis(300);

pub struct StartedLeader {
    pub leader: ProcessGroupLeader,
    pub started_process_id: u32,
    output: Lines<BufReader<ChildStdout>>,
}

pub fn spawn_in_own_group(
    script: &str,
) -> Result<StartedProcess, TestCaseError> {
    Command::new(SHELL)
        .args([SCRIPT_OPTION, script])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .process_group(0)
        .spawn()
        .map_err(|problem| fail_with(&problem))
}

pub fn start_leader(script: &str) -> Result<StartedLeader, TestCaseError> {
    let mut process = spawn_in_own_group(script)?;
    let started_process_id = process.id();
    let output = process
        .stdout
        .take()
        .ok_or_else(|| TestCaseError::fail("the output pipe is missing"))?;
    let leader = ProcessGroupLeader::new(process)
        .map_err(|problem| fail_with(&problem))?;
    Ok(StartedLeader {
        leader,
        started_process_id,
        output: BufReader::new(output).lines(),
    })
}

pub fn script_with_members(member_count: usize, member_setup: &str) -> String {
    let mut script = member_setup.to_owned();
    for _ in 0..member_count {
        script.push_str("sleep 30 & echo $!; ");
    }
    script.push_str("echo ready; wait");
    script
}

impl StartedLeader {
    pub fn read_line(&mut self) -> Result<String, TestCaseError> {
        let line = self
            .output
            .next()
            .ok_or_else(|| TestCaseError::fail("the output ended early"))?;
        line.map_err(|problem| fail_with(&problem))
    }

    pub fn read_until_ready(&mut self) -> Result<Vec<String>, TestCaseError> {
        let mut lines_before_ready = Vec::new();
        loop {
            let line = self.read_line()?;
            if line == READY_LINE {
                return Ok(lines_before_ready);
            }
            lines_before_ready.push(line);
        }
    }

    pub fn wait_for_output_end(&mut self) -> Result<(), TestCaseError> {
        for line in self.output.by_ref() {
            line.map_err(|problem| fail_with(&problem))?;
        }
        thread::sleep(EXIT_SETTLING_TIME);
        Ok(())
    }

    pub fn wait(&mut self) -> Result<ExitStatus, TestCaseError> {
        self.leader.wait().map_err(|problem| fail_with(&problem))
    }

    pub fn process_id_text(&self) -> String {
        self.started_process_id.to_string()
    }
}

pub fn wait_until_finished(
    started: &mut StartedLeader,
) -> Result<ExitStatus, TestCaseError> {
    loop {
        let status = started
            .leader
            .try_wait()
            .map_err(|problem| fail_with(&problem))?;
        if let Some(status) = status {
            return Ok(status);
        }
        thread::sleep(EXIT_SETTLING_TIME);
    }
}

pub fn ensure_no_survivors(
    member_ids: &[String],
) -> Result<(), TestCaseError> {
    let survivors = list_survivors(member_ids)?;
    if survivors.is_empty() {
        return Ok(());
    }
    Err(TestCaseError::fail(format!("still running: {survivors:?}")))
}

pub fn describe_status(status: &ExitStatus) -> DescribedStatus {
    let signal = status.signal().map(ToOwned::to_owned);
    (status.exit_code(), status.success(), signal)
}
