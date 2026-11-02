use std::future::IntoFuture;
use std::io;
use std::sync::Arc;

use tokio::net::TcpListener;

use crate::router::build_router;
use crate::scheduler::run_scheduler;
use crate::server::SharedServer;

pub async fn serve_app_server(
    listener: TcpListener,
    server: SharedServer,
) -> io::Result<()> {
    let router = build_router(Arc::clone(&server));
    let serving = axum::serve(listener, router).into_future();
    tokio::select! {
        serving_outcome = serving => serving_outcome,
        () = run_scheduler(server) => Ok(()),
    }
}
