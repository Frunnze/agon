use std::path::Path;
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use std::time::{Duration, Instant};

use tokio::runtime::Runtime;

use super::agent_placing::find_settings_place;
use super::credential_passing::choose_container_credential;
use super::host_detection::{detect_runner_settings, read_host_facts};
use super::image_check::probe_local_image;
use super::node_runner_server::NodeRunnerServer;
use super::offer_checks::check_offers;
use super::prepared_runner::PreparedRunner;
use super::runner_handle::RunnerHandle;
use crate::agent_credentials::AgentCredential;
use crate::device_roles::can_run_tasks;
use crate::node::Node;
use crate::node_error::NodeError;
use crate::place_offers::PlaceOffer;
use crate::runner_settings::{RunnerChoice, SandboxSettings};
use crate::runner_state::RunnerState;

const IMAGE_RECHECK_INTERVAL: Duration = Duration::from_secs(10);

#[derive(Debug)]
struct RunningRunner {
    working_sandboxes: Vec<SandboxSettings>,
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

        let runner_state = node.runner_state();
        runner_state.record_settings(prepared.starting_settings.clone());
        let offered = prepared.choose_offered_sandboxes(runner_state);
        let credential = choose_container_credential(
            &offered,
            node.agent_credentials().current(),
        );
        let offers_changed = have_offers_changed(runner_state, &offered);

        let mut running_runner = self.lock_runner();
        let running = running_runner.as_ref();
        let credential_changed = running
            .is_some_and(|running| running.container_credential != credential);
        if offers_changed || credential_changed {
            *self.lock_last_image_check() = None;
        }
        let runs_every_offer =
            is_running(running, &offered, credential.as_ref());
        if (runs_every_offer && !offers_changed) || !self.is_image_check_due()
        {
            return Ok(());
        }

        let checked_offers = check_offers(&offered, probe_local_image);
        let working_sandboxes = keep_working(&offered, &checked_offers);
        runner_state.record_checked_offers(checked_offers);
        let running = running_runner.as_ref();
        if is_running(running, &working_sandboxes, credential.as_ref()) {
            return Ok(());
        }
        if let Some(previous) = running_runner.take() {
            previous.handle.stop(runtime);
        }
        if working_sandboxes.is_empty() {
            return Ok(());
        }

        let configuration = prepared.configure_for_device(
            &working_sandboxes,
            credential.as_ref(),
            account.device.id,
        )?;
        let endpoint = Arc::clone(&node.peer_side()?.endpoint);
        let server = NodeRunnerServer::new(Arc::clone(node));
        let handle =
            RunnerHandle::start(runtime, endpoint, server, configuration);
        *running_runner = Some(RunningRunner {
            working_sandboxes,
            container_credential: credential,
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

fn keep_working(
    offered: &[SandboxSettings],
    checked_offers: &[PlaceOffer],
) -> Vec<SandboxSettings> {
    let mut working_sandboxes = Vec::new();
    for (sandbox, checked_offer) in offered.iter().zip(checked_offers) {
        if checked_offer.problem.is_none() {
            working_sandboxes.push(sandbox.clone());
        }
    }
    working_sandboxes
}

fn have_offers_changed(
    runner_state: &RunnerState,
    offered: &[SandboxSettings],
) -> bool {
    let mut checked_places = Vec::new();
    for checked_offer in runner_state.checked_offers() {
        checked_places.push(checked_offer.place);
    }
    let mut offered_places = Vec::new();
    for sandbox in offered {
        offered_places.push(find_settings_place(sandbox));
    }
    checked_places != offered_places
}

fn is_running(
    running: Option<&RunningRunner>,
    sandboxes: &[SandboxSettings],
    container_credential: Option<&AgentCredential>,
) -> bool {
    running.is_some_and(|running| {
        running.working_sandboxes == sandboxes
            && running.container_credential.as_ref() == container_credential
    })
}
