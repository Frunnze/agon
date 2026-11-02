use orchestration_core::device::{Runner, RunnerTarget};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::runner_matching::choose_runner;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::entity_strategies::{available_runner, runner, runner_target};

const MAXIMUM_RUNNERS: usize = 6;

fn free_slots(runner: &Runner) -> u32 {
    runner.slots_total.saturating_sub(runner.slots_busy)
}

fn is_eligible(runner: &Runner, target: &RunnerTarget) -> bool {
    let fits_target = match target {
        RunnerTarget::AnyFreeRunner => true,
        RunnerTarget::SpecificRunner { device_id } => {
            runner.device_id == *device_id
        }
        RunnerTarget::RunnerWithLabels { labels } => {
            labels.iter().all(|label| runner.labels.contains(label))
        }
    };
    fits_target
        && runner.online
        && runner.accepting_new_runs
        && free_slots(runner) > 0
}

fn chosen_runners<'runners>(
    runners: &'runners [Runner],
    chosen: &DeviceId,
    target: &RunnerTarget,
) -> Vec<&'runners Runner> {
    runners
        .iter()
        .filter(|runner| runner.device_id == *chosen)
        .filter(|runner| is_eligible(runner, target))
        .collect()
}

fn mostly_available_runner() -> impl Strategy<Value = Runner> {
    prop_oneof![runner(), available_runner()]
}

fn runner_with_any_slot_counts() -> impl Strategy<Value = Runner> {
    (runner(), any::<u32>(), any::<u32>()).prop_map(
        |(runner, slots_total, slots_busy)| Runner {
            slots_total,
            slots_busy,
            ..runner
        },
    )
}

proptest! {
    #[test]
    fn test_choose_runner_property_picks_an_eligible_runner_or_none(
        target in runner_target(),
        runners in vec(mostly_available_runner(), 0..MAXIMUM_RUNNERS),
    ) {
        let has_eligible =
            runners.iter().any(|runner| is_eligible(runner, &target));

        let chosen = choose_runner(&target, &runners);

        prop_assert_eq!(chosen.is_some(), has_eligible);
        if let Some(device_id) = chosen {
            let matches = chosen_runners(&runners, &device_id, &target);
            prop_assert!(!matches.is_empty());
        }
    }

    #[test]
    fn test_choose_runner_property_most_free_slots_then_lowest_device_id(
        target in runner_target(),
        runners in vec(mostly_available_runner(), 0..MAXIMUM_RUNNERS),
    ) {
        let chosen = choose_runner(&target, &runners);

        if let Some(device_id) = chosen {
            let chosen_matches = chosen_runners(&runners, &device_id, &target);
            let chosen_free_slots = chosen_matches
                .iter()
                .map(|runner| free_slots(runner))
                .max()
                .unwrap_or_default();
            for other in runners.iter().filter(|runner| {
                is_eligible(runner, &target)
            }) {
                let other_free_slots = free_slots(other);
                prop_assert!(other_free_slots <= chosen_free_slots);
                if other_free_slots == chosen_free_slots {
                    prop_assert!(device_id <= other.device_id);
                }
            }
        }
    }

    #[test]
    fn test_choose_runner_property_ignores_the_order_of_runners(
        target in runner_target(),
        runners in vec(mostly_available_runner(), 0..MAXIMUM_RUNNERS),
    ) {
        let reversed: Vec<Runner> = runners.iter().rev().cloned().collect();

        prop_assert_eq!(
            choose_runner(&target, &runners),
            choose_runner(&target, &reversed)
        );
    }

    #[test]
    fn test_choose_runner_fuzz_arbitrary_runners_give_a_defined_answer(
        target in runner_target(),
        runners in vec(runner_with_any_slot_counts(), 0..MAXIMUM_RUNNERS),
    ) {
        let chosen = choose_runner(&target, &runners);

        let has_eligible =
            runners.iter().any(|runner| is_eligible(runner, &target));
        prop_assert_eq!(chosen.is_some(), has_eligible);
    }
}
