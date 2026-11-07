use std::thread::{self, ScopedJoinHandle};

use serde_json::Value;

pub type CommandOutcome = Result<Value, String>;
pub type CommandTask<'task> = &'task (dyn Fn() -> CommandOutcome + Sync);

const THREAD_PANICKED: &str = "the thread panicked";

pub fn run_at_once(
    thread_count: usize,
    task: CommandTask<'_>,
) -> Vec<CommandOutcome> {
    thread::scope(|scope| {
        let mut running = Vec::new();
        for _ in 0..thread_count {
            running.push(scope.spawn(task));
        }
        let mut outcomes = Vec::new();
        for handle in running {
            outcomes.push(join_outcome(handle));
        }
        outcomes
    })
}

pub fn run_both_at_once(
    first_task: CommandTask<'_>,
    second_task: CommandTask<'_>,
) -> (CommandOutcome, CommandOutcome) {
    thread::scope(|scope| {
        let first_running = scope.spawn(first_task);
        let second_running = scope.spawn(second_task);
        (join_outcome(first_running), join_outcome(second_running))
    })
}

fn join_outcome(
    handle: ScopedJoinHandle<'_, CommandOutcome>,
) -> CommandOutcome {
    handle
        .join()
        .unwrap_or_else(|_| Err(THREAD_PANICKED.to_owned()))
}
