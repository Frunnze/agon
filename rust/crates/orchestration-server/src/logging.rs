use std::fmt::Display;

use crate::error::ServerError;

pub fn log_scheduler_failure(problem: &ServerError) {
    eprintln!("scheduler could not start jobs: {problem}");
}

pub fn log_requeue_failure(problem: &ServerError) {
    eprintln!("scheduler could not requeue abandoned steps: {problem}");
}

pub fn log_setup_code(setup_code: &str) {
    eprintln!("account setup code (shown once): {setup_code}");
}

pub fn log_listening(listen_address: &str) {
    eprintln!("orchestration server listening on {listen_address}");
}

pub fn log_startup_failure(problem: &impl Display) {
    eprintln!("orchestration server could not start: {problem}");
}
