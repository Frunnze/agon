use std::time::Duration;

use axum::Json;
use axum::extract::State;
use axum::http::{StatusCode, header};
use axum::response::{IntoResponse, Response};
use orchestration_api::server_group::{
    JoinServerGroupRequest, ReplicaQuery, ServerGroupView,
};
use orchestration_core::identifiers::DeviceId;
use tokio::time::timeout;

use crate::authentication::SignedRequest;
use crate::error::ServerError;
use crate::extractors::{PathValue, QueryValue, parse_json_body};
use crate::server::SharedServer;
use crate::server_group_changes::remove_member;

pub const REPLICA_WAIT: Duration = Duration::from_secs(5);
const JSON_CONTENT_TYPE: &str = "application/json";

pub async fn show_server_group(
    State(server): State<SharedServer>,
    _request: SignedRequest,
) -> Result<Json<ServerGroupView>, ServerError> {
    Ok(Json(server.describe_group()?))
}

pub async fn register_server_member(
    State(server): State<SharedServer>,
    request: SignedRequest,
) -> Result<Json<ServerGroupView>, ServerError> {
    request.caller.require_client()?;
    let join_request: JoinServerGroupRequest = parse_json_body(&request.body)?;
    server.register_member(&request.caller.device_id, &join_request.member)?;
    Ok(Json(server.describe_group()?))
}

pub async fn remove_server_member(
    State(server): State<SharedServer>,
    PathValue(device_text): PathValue<String>,
    request: SignedRequest,
) -> Result<Json<ServerGroupView>, ServerError> {
    let caller = &request.caller.device_id;
    let device_id = DeviceId(device_text);
    server.apply(caller, |state, _now| {
        remove_member(state, caller, &device_id)
    })?;
    Ok(Json(server.describe_group()?))
}

pub async fn fetch_replica(
    State(server): State<SharedServer>,
    QueryValue(query): QueryValue<ReplicaQuery>,
    request: SignedRequest,
) -> Result<Response, ServerError> {
    let caller = &request.caller.device_id;
    let is_member = server.read(|state| {
        let member = state.server_group.find_member_of_device(caller);
        Ok(member.is_some())
    })?;
    if !is_member {
        return Err(ServerError::Forbidden(
            "only a device keeping the app server can copy it",
        ));
    }
    server.record_copy_request(caller, query.after)?;

    let mut revisions = server.subscribe_to_revisions();
    let newer_revision = revisions.wait_for(|latest| *latest > query.after);
    let replica_wait = server.settings().long_poll_timeout.min(REPLICA_WAIT);
    let changed_in_time = timeout(replica_wait, newer_revision)
        .await
        .is_ok_and(|waited| waited.is_ok());
    if !changed_in_time {
        return Ok(StatusCode::NO_CONTENT.into_response());
    }
    let replica_bytes = server.read(|state| {
        serde_json::to_vec(state)
            .map_err(|problem| ServerError::Storage(problem.to_string()))
    })?;
    let content_type = [(header::CONTENT_TYPE, JSON_CONTENT_TYPE)];
    Ok((content_type, replica_bytes).into_response())
}
