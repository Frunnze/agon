use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use orchestration_core::identifiers::DeviceId;
use orchestration_runner::runner_configuration::RunnerConfiguration;

use super::agent_placing::{find_settings_place, offer_sandboxes};
use super::configuration_building::build_runner_configuration;
use super::credential_passing::pass_agent_credential;
use super::host_detection::{detect_container_sandbox, read_host_facts};
use crate::agent_credentials::AgentCredential;
use crate::node_error::NodeError;
use crate::runner_settings::{RunnerSettings, SandboxSettings};
use crate::runner_state::RunnerState;

#[derive(Debug)]
pub(super) struct PreparedRunner {
    pub(super) starting_settings: RunnerSettings,
    detected_container: SandboxSettings,
    data_directory: PathBuf,
    process_environment: BTreeMap<String, String>,
}

impl PreparedRunner {
    pub(super) fn prepare(
        starting_settings: RunnerSettings,
        data_directory: &Path,
    ) -> Result<Self, NodeError> {
        let process_environment: BTreeMap<String, String> =
            std::env::vars().collect();
        build_runner_configuration(
            &starting_settings,
            std::slice::from_ref(&starting_settings.sandbox),
            data_directory,
            &process_environment,
        )?;
        Ok(Self {
            starting_settings,
            detected_container: detect_container_sandbox(&read_host_facts()),
            data_directory: data_directory.to_path_buf(),
            process_environment,
        })
    }

    pub(super) fn choose_offered_sandboxes(
        &self,
        runner_state: &RunnerState,
    ) -> Vec<SandboxSettings> {
        let starting_place =
            find_settings_place(&self.starting_settings.sandbox);
        let offers = runner_state
            .chosen_offers()
            .unwrap_or_else(|| vec![starting_place]);
        offer_sandboxes(
            &self.starting_settings,
            &offers,
            &self.detected_container,
        )
    }

    pub(super) fn configure_for_device(
        &self,
        working_sandboxes: &[SandboxSettings],
        container_credential: Option<&AgentCredential>,
        device_id: DeviceId,
    ) -> Result<RunnerConfiguration, NodeError> {
        let built = build_runner_configuration(
            &self.starting_settings,
            working_sandboxes,
            &self.data_directory,
            &self.process_environment,
        )?;
        let clone_source = built.clone_source.on_device(device_id);
        let mut sandboxes = Vec::new();
        for sandbox in &built.sandboxes {
            sandboxes
                .push(pass_agent_credential(sandbox, container_credential));
        }
        Ok(RunnerConfiguration {
            clone_source,
            sandboxes,
            ..built
        })
    }
}
