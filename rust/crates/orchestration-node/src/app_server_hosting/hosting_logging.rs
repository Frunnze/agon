use crate::node_error::NodeError;

pub(super) fn log_keeper_problem(problem: &NodeError) {
    eprintln!("the app server group keeper hit a problem: {problem}");
}

pub(super) fn log_backup_cleanup_problem(problem: &NodeError) {
    eprintln!("the unfinished app server backup was not removed: {problem}");
}
