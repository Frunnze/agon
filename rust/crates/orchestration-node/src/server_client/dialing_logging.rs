use crate::node_error::NodeError;

pub(super) fn log_local_search_problem(problem: &NodeError) {
    eprintln!("the local network search for an app server failed: {problem}");
}
