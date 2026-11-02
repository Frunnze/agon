use std::cmp::Ordering;

use crate::device::{Runner, RunnerTarget};
use crate::identifiers::DeviceId;

#[must_use]
pub fn choose_runner(
    target: &RunnerTarget,
    runners: &[Runner],
) -> Option<DeviceId> {
    let best_runner = runners
        .iter()
        .filter(|runner| can_take_new_run(runner))
        .filter(|runner| matches_target(runner, target))
        .min_by(|first, second| compare_preference(first, second));
    best_runner.map(|runner| runner.device_id.clone())
}

fn can_take_new_run(runner: &Runner) -> bool {
    runner.online && runner.accepting_new_runs && count_free_slots(runner) > 0
}

fn matches_target(runner: &Runner, target: &RunnerTarget) -> bool {
    match target {
        RunnerTarget::AnyFreeRunner => true,
        RunnerTarget::SpecificRunner { device_id } => {
            runner.device_id == *device_id
        }
        RunnerTarget::RunnerWithLabels { labels } => {
            labels.iter().all(|label| runner.labels.contains(label))
        }
    }
}

fn compare_preference(first: &Runner, second: &Runner) -> Ordering {
    let more_free_slots_first =
        count_free_slots(second).cmp(&count_free_slots(first));
    more_free_slots_first.then_with(|| first.device_id.cmp(&second.device_id))
}

fn count_free_slots(runner: &Runner) -> u32 {
    runner.slots_total.saturating_sub(runner.slots_busy)
}
