use std::io;
use std::process::Child as StartedProcess;
use std::thread;
use std::time::Duration;

use nix::errno::Errno;
use nix::sys::signal::{Signal, killpg};
use nix::unistd::Pid;
use portable_pty::{Child, ChildKiller, ExitStatus};

const HANG_UP_GRACE_PERIOD: Duration = Duration::from_millis(250);

#[derive(Debug)]
pub struct ProcessGroupLeader {
    process: StartedProcess,
    group: Pid,
}

#[derive(Debug)]
struct ProcessGroupKiller {
    group: Pid,
}

impl ProcessGroupLeader {
    pub fn new(process: StartedProcess) -> io::Result<Self> {
        let group = find_group(process.id())?;
        Ok(Self { process, group })
    }
}

impl ChildKiller for ProcessGroupLeader {
    fn kill(&mut self) -> io::Result<()> {
        stop_process_group(self.group)
    }

    fn clone_killer(&self) -> Box<dyn ChildKiller + Send + Sync> {
        Box::new(ProcessGroupKiller { group: self.group })
    }
}

impl Child for ProcessGroupLeader {
    fn try_wait(&mut self) -> io::Result<Option<ExitStatus>> {
        let status = self.process.try_wait()?;
        Ok(status.map(ExitStatus::from))
    }

    fn wait(&mut self) -> io::Result<ExitStatus> {
        let status = self.process.wait()?;
        Ok(ExitStatus::from(status))
    }

    fn process_id(&self) -> Option<u32> {
        Some(self.process.id())
    }
}

impl ChildKiller for ProcessGroupKiller {
    fn kill(&mut self) -> io::Result<()> {
        stop_process_group(self.group)
    }

    fn clone_killer(&self) -> Box<dyn ChildKiller + Send + Sync> {
        Box::new(ProcessGroupKiller { group: self.group })
    }
}

fn find_group(process_id: u32) -> io::Result<Pid> {
    let raw_process_id = i32::try_from(process_id)
        .map_err(|problem| io::Error::other(problem.to_string()))?;
    Ok(Pid::from_raw(raw_process_id))
}

fn stop_process_group(group: Pid) -> io::Result<()> {
    send_to_group(group, Signal::SIGHUP)?;
    thread::sleep(HANG_UP_GRACE_PERIOD);
    send_to_group(group, Signal::SIGKILL)
}

fn send_to_group(group: Pid, signal: Signal) -> io::Result<()> {
    match killpg(group, signal) {
        Ok(()) => Ok(()),
        Err(problem) if is_group_already_gone(problem) => Ok(()),
        Err(problem) => Err(io::Error::from(problem)),
    }
}

const fn is_group_already_gone(problem: Errno) -> bool {
    let has_no_process = matches!(problem, Errno::ESRCH);
    let has_only_exited_processes = matches!(problem, Errno::EPERM);
    has_no_process || has_only_exited_processes
}
