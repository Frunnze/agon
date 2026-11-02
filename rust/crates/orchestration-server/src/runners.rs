use axum::Json;
use axum::extract::State;
use chrono::{DateTime, TimeDelta, Utc};
use orchestration_api::updates::ChangeTopic;
use orchestration_api::work::{HeartbeatRequest, SetAcceptingRunsRequest};
use orchestration_core::device::Runner;
use orchestration_core::identifiers::DeviceId;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::device_registration::name_device;
use crate::error::ServerError;
use crate::extractors::{PathValue, parse_json_body};
use crate::request_ledger::Presence;
use crate::server::SharedServer;
use crate::stored_state::StoredState;

const RUNNER_PRESENCE_TIMEOUT: TimeDelta = TimeDelta::seconds(60);

pub async fn list_runners(
    State(server): State<SharedServer>,
    _request: SignedRequest,
) -> Result<Json<Vec<Runner>>, ServerError> {
    let presence = server.presence_snapshot()?;
    let now = server.now();
    let runners =
        server.read(|state| Ok(present_runners(state, &presence, now)))?;
    Ok(Json(runners))
}

pub async fn receive_heartbeat(
    State(server): State<SharedServer>,
    request: SignedRequest,
) -> Result<Json<Runner>, ServerError> {
    request.caller.require_runner()?;
    let heartbeat: HeartbeatRequest = parse_json_body(&request.body)?;
    let runner_id = &request.caller.device_id;
    let runner = server.apply(runner_id, |state, _now| {
        record_heartbeat(state, runner_id, &heartbeat)
    })?;
    Ok(Json(runner))
}

pub async fn set_accepting_runs(
    State(server): State<SharedServer>,
    PathValue(device_text): PathValue<String>,
    request: SignedRequest,
) -> Result<Json<Runner>, ServerError> {
    request.caller.require_client()?;
    let accepting: SetAcceptingRunsRequest = parse_json_body(&request.body)?;
    let runner_id = DeviceId(device_text);
    let runner = server.apply(&request.caller.device_id, |state, _now| {
        switch_accepting(state, &runner_id, accepting.accepting_new_runs)
    })?;
    Ok(Json(runner))
}

pub fn present_runners(
    state: &StoredState,
    presence: &Presence,
    now: DateTime<Utc>,
) -> Vec<Runner> {
    state
        .runners
        .values()
        .map(|runner| apply_presence(runner, presence, now))
        .collect()
}

fn apply_presence(
    runner: &Runner,
    presence: &Presence,
    now: DateTime<Utc>,
) -> Runner {
    let online = presence.get(&runner.device_id).is_some_and(|seen_at| {
        now.signed_duration_since(*seen_at) <= RUNNER_PRESENCE_TIMEOUT
    });
    Runner {
        online,
        ..runner.clone()
    }
}

fn record_heartbeat(
    state: &mut StoredState,
    runner_id: &DeviceId,
    heartbeat: &HeartbeatRequest,
) -> Result<Change<Runner>, ServerError> {
    if heartbeat.slots_busy > heartbeat.slots_total {
        return Err(ServerError::Invalid(
            "a runner cannot use more slots than it has".to_owned(),
        ));
    }
    let existing = state.runners.get(runner_id);
    let accepting_new_runs =
        existing.is_none_or(|runner| runner.accepting_new_runs);
    let runner = Runner {
        device_id: runner_id.clone(),
        labels: heartbeat.labels.clone(),
        slots_total: heartbeat.slots_total,
        slots_busy: heartbeat.slots_busy,
        link: heartbeat.link,
        online: true,
        accepting_new_runs,
        sandbox: heartbeat.sandbox,
        allowed_hosts: heartbeat.allowed_hosts.clone(),
        cached_repositories: heartbeat.cached_repositories.clone(),
    };
    if existing == Some(&runner) {
        return Ok(Change::unchanged(runner));
    }

    state.runners.insert(runner_id.clone(), runner.clone());
    let event_text = format!(
        "{} reported {} of {} slots busy",
        name_device(state, runner_id),
        runner.slots_busy,
        runner.slots_total
    );
    Ok(Change::recorded(runner, ChangeTopic::Runners, event_text))
}

fn switch_accepting(
    state: &mut StoredState,
    runner_id: &DeviceId,
    accepting_new_runs: bool,
) -> Result<Change<Runner>, ServerError> {
    let runner = state
        .runners
        .get_mut(runner_id)
        .ok_or(ServerError::NotFound("the runner"))?;
    if runner.accepting_new_runs == accepting_new_runs {
        return Ok(Change::unchanged(runner.clone()));
    }
    runner.accepting_new_runs = accepting_new_runs;
    let switched = runner.clone();
    let verb = if accepting_new_runs {
        "Resumed"
    } else {
        "Paused"
    };
    let event_text =
        format!("{verb} new runs on {}", name_device(state, runner_id));
    Ok(Change::recorded(switched, ChangeTopic::Runners, event_text))
}
