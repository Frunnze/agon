use std::path::Path;
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use std::time::{Duration, Instant};

use tokio::runtime::Runtime;

use super::credential_passing::choose_container_credential;
use super::host_detection::{detect_runner_settings, read_host_facts};
use super::image_check::{describe_image_problem, probe_local_image};
use super::node_runner_server::NodeRunnerServer;
use super::prepared_runner::PreparedRunner;
use super::runner_handle::RunnerHandle;
use crate::agent_credentials::AgentCredential;
use crate::device_roles::can_run_tasks;
use crate::node::Node;
use crate::node_error::NodeError;
use crate::runner_settings::{RunnerChoice, RunnerSettings};
use crate::runner_state::RunnerState;

const IMAGE_RECHECK_INTERVAL: Duration = Duration::from_secs(10);

#[derive(Debug)]
struct RunningRunner {
    settings: RunnerSettings,
    container_credential: Option<AgentCredential>,
    handle: RunnerHandle,
}

type RunnerSlot = Option<RunningRunner>;

#[derive(Debug)]
pub(crate) struct RunnerLauncher {
    prepared: Option<PreparedRunner>,
    running_runner: Mutex<RunnerSlot>,
    last_image_check: Mutex<Option<Instant>>,
}

impl RunnerLauncher {
    pub(crate) fn prepare(
        choice: Option<&RunnerChoice>,
        data_directory: &Path,
    ) -> Result<Self, NodeError> {
        let starting_settings = match choice {
            Some(RunnerChoice::Off(_)) => None,
            Some(RunnerChoice::Given(settings)) => Some(settings.clone()),
            None => Some(detect_runner_settings(&read_host_facts())),
        };
        let prepared = match starting_settings {
            Some(settings) => {
                Some(PreparedRunner::prepare(settings, data_directory)?)
            }
            None => None,
        };
        Ok(Self {
            prepared,
            running_runner: Mutex::new(None),
            last_image_check: Mutex::new(None),
        })
    }

    pub(crate) fn start_when_ready(
        &self,
        runtime: &Runtime,
        node: &Arc<Node>,
    ) -> Result<(), NodeError> {
        let Some(prepared) = &self.prepared else {
            return Ok(());
        };
        let Some(account) = node.device_files().load_account()? else {
            return Ok(());
        };
        if !can_run_tasks(account.device.role) {
            return Ok(());
        }

        let settings = prepared.choose_settings(node.runner_state());
        let container_credential = choose_container_credential(
            &settings.sandbox,
            node.agent_credentials().current(),
        );
        let mut running_runner = self.lock_runner();
        if let Some(running) = running_runner.as_ref()
            && running.settings == settings
            && running.container_credential == container_credential
        {
            return Ok(());
        }
        if let Some(previous) = running_runner.take() {
            previous.handle.stop(runtime);
        }
        self.record_settings(node.runner_state(), &settings);
        if !self.passes_due_image_check(node.runner_state(), &settings) {
            return Ok(());
        }

        let configuration = prepared.configure_for_device(
            &settings,
            container_credential.as_ref(),
            account.device.id,
        )?;
        let endpoint = Arc::clone(&node.peer_side()?.endpoint);
        let server = NodeRunnerServer::new(Arc::clone(node));
        let handle =
            RunnerHandle::start(runtime, endpoint, server, configuration);
        *running_runner = Some(RunningRunner {
            settings,
            container_credential,
            handle,
        });
        Ok(())
    }

    pub(crate) fn stop(&mut self, runtime: &Runtime) {
        let running_runner = self
            .running_runner
            .get_mut()
            .unwrap_or_else(PoisonError::into_inner)
            .take();
        if let Some(running) = running_runner {
            running.handle.stop(runtime);
        }
    }

    fn record_settings(
        &self,
        runner_state: &RunnerState,
        settings: &RunnerSettings,
    ) {
        let in_effect = runner_state.settings_in_effect();
        if in_effect.as_ref() == Some(settings) {
            return;
        }
        runner_state.record_settings(settings.clone());
        *self.lock_last_image_check() = None;
    }

    fn passes_due_image_check(
        &self,
        runner_state: &RunnerState,
        settings: &RunnerSettings,
    ) -> bool {
        if !self.is_image_check_due() {
            return false;
        }
        let image_problem =
            describe_image_problem(&settings.sandbox, probe_local_image);
        let passes = image_problem.is_none();
        runner_state.record_problem(image_problem);
        passes
    }

    fn is_image_check_due(&self) -> bool {
        let mut last_check = self.lock_last_image_check();
        let now = Instant::now();
        let is_due = last_check.is_none_or(|checked_at| {
            now.duration_since(checked_at) >= IMAGE_RECHECK_INTERVAL
        });
        if is_due {
            *last_check = Some(now);
        }
        is_due
    }

    fn lock_last_image_check(&self) -> MutexGuard<'_, Option<Instant>> {
        self.last_image_check
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
    }

    fn lock_runner(&self) -> MutexGuard<'_, RunnerSlot> {
        self.running_runner
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
    }
}
