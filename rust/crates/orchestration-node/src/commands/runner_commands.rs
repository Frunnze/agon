use orchestration_api::work::SetAcceptingRunsRequest;
use orchestration_core::device::{Device, Runner};
use orchestration_core::identifiers::{DeviceId, WorkspaceId};
use orchestration_core::peer_address::SignedPeerAddress;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::command_reply::encode_reply;
use crate::node::Node;
use crate::node_error::NodeError;
use crate::peer_side::trusted_peer_address;
use crate::place_offers::PlaceOffer;
use crate::runner_settings::RunnerSettings;
use crate::views::{
    RunnerSummary, describe_runner_summary, summarize_runners,
};

pub(super) const RUNNER_COMMAND_NAMES: [&str; 3] =
    ["list_runners", "pause_runner", "resume_runner"];

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum RunnerCommand {
    ListRunners { workspace_id: WorkspaceId },
    PauseRunner { device_id: DeviceId },
    ResumeRunner { device_id: DeviceId },
}

#[derive(Debug, Serialize)]
struct RunnerView {
    runner: Runner,
    device_name: String,
    free_slots: u32,
    peer_address: Option<SignedPeerAddress>,
    peer_address_verified: bool,
}

#[derive(Debug, Serialize)]
struct RunnersView {
    summary: RunnerSummary,
    summary_text: String,
    runners: Vec<RunnerView>,
    this_device_problem: Option<String>,
    this_device_settings: Option<RunnerSettings>,
    this_device_offers: Option<Vec<PlaceOffer>>,
}

pub(super) async fn handle_runner_command(
    node: &Node,
    command: RunnerCommand,
) -> Result<Value, NodeError> {
    let session = node.open_session()?;
    let client = session.client();
    match command {
        RunnerCommand::ListRunners { workspace_id } => {
            let runners = client.list_runners().await?;
            let devices = client.list_devices().await?;
            let mut view =
                build_runners_view(&runners, &devices, workspace_id);
            let runner_state = node.runner_state();
            view.this_device_problem = runner_state.problem();
            view.this_device_settings = runner_state.settings_in_effect();
            if view.this_device_settings.is_some() {
                view.this_device_offers = Some(runner_state.checked_offers());
            }
            encode_reply(&view)
        }
        RunnerCommand::PauseRunner { device_id } => {
            let request = SetAcceptingRunsRequest {
                accepting_new_runs: false,
            };
            client.set_accepting_runs(&device_id, &request).await?;
            Ok(Value::Null)
        }
        RunnerCommand::ResumeRunner { device_id } => {
            let request = SetAcceptingRunsRequest {
                accepting_new_runs: true,
            };
            client.set_accepting_runs(&device_id, &request).await?;
            Ok(Value::Null)
        }
    }
}

fn build_runners_view(
    runners: &[Runner],
    devices: &[Device],
    workspace_id: WorkspaceId,
) -> RunnersView {
    let mut workspace_runners = Vec::new();
    let mut runner_views = Vec::new();
    for runner in runners {
        let device = devices.iter().find(|device| {
            device.id == runner.device_id
                && device.workspaces.contains(&workspace_id)
                && !device.revoked
        });
        let Some(device) = device else {
            continue;
        };
        workspace_runners.push(runner.clone());
        runner_views.push(RunnerView {
            runner: runner.clone(),
            device_name: device.name.clone(),
            free_slots: runner.slots_total.saturating_sub(runner.slots_busy),
            peer_address: device.peer_address.clone(),
            peer_address_verified: trusted_peer_address(device).is_ok(),
        });
    }

    let summary = summarize_runners(&workspace_runners);
    RunnersView {
        summary,
        summary_text: describe_runner_summary(&summary),
        runners: runner_views,
        this_device_problem: None,
        this_device_settings: None,
        this_device_offers: None,
    }
}
