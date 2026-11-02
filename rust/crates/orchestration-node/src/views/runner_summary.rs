use orchestration_core::device::Runner;
use serde::Serialize;

const PART_SEPARATOR: &str = " · ";

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize)]
pub struct RunnerSummary {
    pub runner_count: usize,
    pub online_count: usize,
    pub free_slot_count: u32,
}

#[must_use]
pub fn summarize_runners(runners: &[Runner]) -> RunnerSummary {
    let mut summary = RunnerSummary {
        runner_count: runners.len(),
        ..RunnerSummary::default()
    };
    for runner in runners {
        if runner.online {
            summary.online_count += 1;
            let free_slots =
                runner.slots_total.saturating_sub(runner.slots_busy);
            summary.free_slot_count += free_slots;
        }
    }
    summary
}

#[must_use]
pub fn describe_runner_summary(summary: &RunnerSummary) -> String {
    let slot_word = if summary.free_slot_count == 1 {
        "slot"
    } else {
        "slots"
    };
    format!(
        "{} of {} online{PART_SEPARATOR}{} free {slot_word}",
        summary.online_count, summary.runner_count, summary.free_slot_count
    )
}
