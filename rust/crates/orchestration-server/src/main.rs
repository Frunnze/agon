use std::process::ExitCode;
use std::sync::Arc;

use orchestration_server::{
    CommandLineError, EVENTS_LONG_POLL_TIMEOUT, Server, ServerError,
    ServerSettings, SystemClock, log_listening, log_setup_code,
    log_startup_failure, parse_command_line, serve_app_server,
};
use thiserror::Error;
use tokio::net::TcpListener;

const PROGRAM_NAME_ARGUMENTS: usize = 1;

#[derive(Debug, Error)]
enum StartupError {
    #[error(transparent)]
    CommandLine(#[from] CommandLineError),
    #[error(transparent)]
    Server(#[from] ServerError),
    #[error("the network failed: {0}")]
    Network(#[from] std::io::Error),
}

#[tokio::main]
async fn main() -> ExitCode {
    match serve().await {
        Ok(()) => ExitCode::SUCCESS,
        Err(problem) => {
            log_startup_failure(&problem);
            ExitCode::FAILURE
        }
    }
}

async fn serve() -> Result<(), StartupError> {
    let arguments = std::env::args().skip(PROGRAM_NAME_ARGUMENTS);
    let command_line = parse_command_line(arguments)?;
    let settings = ServerSettings {
        data_directory: command_line.data_directory,
        public_address: command_line.public_address,
        long_poll_timeout: EVENTS_LONG_POLL_TIMEOUT,
    };
    let server = Arc::new(Server::open(settings, Arc::new(SystemClock))?);
    if let Some(setup_code) = server.newly_issued_setup_code() {
        log_setup_code(setup_code);
    }
    let listener = TcpListener::bind(&command_line.listen_address).await?;

    log_listening(&command_line.listen_address);
    serve_app_server(listener, server).await?;
    Ok(())
}
