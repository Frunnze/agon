use std::io;
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};

use portable_pty::Child;
#[cfg(not(unix))]
use portable_pty::ChildKiller;

#[cfg(unix)]
use crate::process_group::{find_group, stop_process_group};
use crate::process_supervisor::{ProcessExit, describe_exit_status};

#[cfg(unix)]
const NO_PROCESS_ID: &str = "the terminal program has no process id";

pub(crate) type SharedTerminalChild = Arc<Mutex<TerminalChild>>;

pub(crate) struct TerminalChild {
    child: Box<dyn Child + Send + Sync>,
    exit: Option<ProcessExit>,
}

impl TerminalChild {
    pub(crate) fn share(
        child: Box<dyn Child + Send + Sync>,
    ) -> SharedTerminalChild {
        Arc::new(Mutex::new(Self { child, exit: None }))
    }

    pub(crate) fn check_exit(&mut self) -> io::Result<Option<ProcessExit>> {
        if self.exit.is_none() {
            let status = self.child.try_wait()?;
            self.exit = status.map(|status| describe_exit_status(&status));
        }
        Ok(self.exit.clone())
    }

    pub(crate) fn stop(&mut self) -> io::Result<()> {
        if self.check_exit()?.is_some() {
            return Ok(());
        }
        stop_program(self.child.as_mut())
    }
}

pub(crate) fn lock_terminal_child(
    child: &SharedTerminalChild,
) -> MutexGuard<'_, TerminalChild> {
    child.lock().unwrap_or_else(PoisonError::into_inner)
}

#[cfg(unix)]
fn stop_program(child: &mut (dyn Child + Send + Sync)) -> io::Result<()> {
    let process_id = child
        .process_id()
        .ok_or_else(|| io::Error::other(NO_PROCESS_ID))?;
    stop_process_group(find_group(process_id)?)
}

#[cfg(not(unix))]
fn stop_program(child: &mut (dyn Child + Send + Sync)) -> io::Result<()> {
    child.kill()
}
