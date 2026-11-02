use axum::Json;
use axum::extract::State;
use orchestration_api::updates::{
    ChangeNotification, ChangeTopic, EventsQuery, EventsResponse,
};
use tokio::time::timeout;

use crate::authentication::SignedRequest;
use crate::error::ServerError;
use crate::extractors::QueryValue;
use crate::server::SharedServer;
use crate::stored_state::StoredState;

const MAXIMUM_KEPT_NOTIFICATIONS: usize = 1_000;

pub async fn poll_events(
    State(server): State<SharedServer>,
    QueryValue(query): QueryValue<EventsQuery>,
    _request: SignedRequest,
) -> Result<Json<EventsResponse>, ServerError> {
    let mut changes = server.subscribe_to_changes();
    let after = query.after;
    let current = server.read(|state| Ok(collect_events(state, after)))?;
    let is_ahead_of_server = after > current.latest_sequence;
    if !current.notifications.is_empty() || is_ahead_of_server {
        return Ok(Json(current));
    }

    let newer_change = changes.wait_for(|latest| *latest > after);
    let long_poll_timeout = server.settings().long_poll_timeout;
    let changed_in_time = timeout(long_poll_timeout, newer_change)
        .await
        .is_ok_and(|waited| waited.is_ok());
    if !changed_in_time {
        return Ok(Json(current));
    }
    let newer = server.read(|state| Ok(collect_events(state, after)))?;
    Ok(Json(newer))
}

pub fn append_notification(state: &mut StoredState, topic: ChangeTopic) {
    state.latest_sequence = state.latest_sequence.saturating_add(1);
    state.notifications.push(ChangeNotification {
        sequence: state.latest_sequence,
        topic,
    });
    let excess = state
        .notifications
        .len()
        .saturating_sub(MAXIMUM_KEPT_NOTIFICATIONS);
    state.notifications.drain(..excess);
}

fn collect_events(state: &StoredState, after: u64) -> EventsResponse {
    let notifications = state
        .notifications
        .iter()
        .filter(|notification| notification.sequence > after)
        .cloned()
        .collect();
    EventsResponse {
        notifications,
        latest_sequence: state.latest_sequence,
    }
}
