use axum::extract::{Request, State};
use axum::middleware::Next;
use axum::response::{IntoResponse, Response};
use orchestration_api::routes::SERVER_GROUP;
use orchestration_core::server_group::ServerStanding;

use crate::error::ServerError;
use crate::server::SharedServer;

pub async fn refuse_on_backup(
    State(server): State<SharedServer>,
    request: Request,
    next: Next,
) -> Response {
    let is_group_view = request.uri().path() == SERVER_GROUP;
    if server.standing() == ServerStanding::Backup && !is_group_view {
        return ServerError::NotActive.into_response();
    }
    next.run(request).await
}
