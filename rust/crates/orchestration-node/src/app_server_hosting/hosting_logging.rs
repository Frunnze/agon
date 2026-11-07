use std::io;

use orchestration_server::ServerError;

use crate::node_error::NodeError;

pub(super) fn log_keeper_problem(problem: &NodeError) {
    eprintln!("the app server group keeper hit a problem: {problem}");
}

pub(super) fn log_backup_cleanup_problem(problem: &NodeError) {
    eprintln!("the unfinished app server backup was not removed: {problem}");
}

pub(super) fn log_web_serving_problem(problem: &io::Error) {
    eprintln!("the hosted app server stopped serving: {problem}");
}

pub(super) fn log_write_stopping_problem(problem: &ServerError) {
    eprintln!("the stopped app server could not refuse writes: {problem}");
}
