use std::cmp::Reverse;
use std::ops::RangeInclusive;

use orchestration_core::device::{Runner, RunnerTarget};
use orchestration_core::identifiers::DeviceId;
use orchestration_core::runner_matching::choose_runner;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::entity_strategies::{
    available_runner, device_identifier, label, runner, runner_target,
};

const MAXIMUM_RUNNERS: usize = 6;
const LARGE_SLOT_COUNTS: RangeInclusive<u32> = u32::MAX - 8..=u32::MAX;

fn uniquely_named(runners: &[Runner]) -> Vec<Runner> {
    let mut named = Vec::new();
    for (index, runner) in runners.iter().enumerate() {
        named.push(Runner {
            device_id: DeviceId(format!("runner-{index}")),
            ..runner.clone()
        });
    }
    named
}

fn available_runners() -> impl Strategy<Value = Vec<Runner>> {
    vec(available_runner(), 1..MAXIMUM_RUNNERS)
        .prop_map(|runners| uniquely_named(&runners))
}

fn free_slots(runner: &Runner) -> u32 {
    runner.slots_total.saturating_sub(runner.slots_busy)
}

fn find_runner<'list>(
    runners: &'list [Runner],
    device_id: Option<&DeviceId>,
) -> Option<&'list Runner> {
    runners
        .iter()
        .find(|runner| Some(&runner.device_id) == device_id)
}

fn has_labels(runner: &Runner, labels: &[String]) -> bool {
    labels.iter().all(|label| runner.labels.contains(label))
}

proptest! {
    #[test]
    fn test_can_take_new_run_property_offline_runners_are_never_chosen(
        runners in vec(available_runner(), 0..MAXIMUM_RUNNERS),
        target in runner_target(),
    ) {
        let mut offline_runners = Vec::new();
        for runner in &runners {
            offline_runners.push(Runner { online: false, ..runner.clone() });
        }

        prop_assert_eq!(choose_runner(&target, &offline_runners), None);
    }

    #[test]
    fn test_can_take_new_run_property_paused_runners_are_never_chosen(
        runners in vec(available_runner(), 0..MAXIMUM_RUNNERS),
        target in runner_target(),
    ) {
        let mut paused_runners = Vec::new();
        for runner in &runners {
            paused_runners.push(Runner {
                accepting_new_runs: false,
                ..runner.clone()
            });
        }

        prop_assert_eq!(choose_runner(&target, &paused_runners), None);
    }

    #[test]
    fn test_can_take_new_run_property_full_runners_are_never_chosen(
        runners in vec(available_runner(), 0..MAXIMUM_RUNNERS),
        extra_busy in prop_oneof![Just(0_u32), any::<u32>()],
        target in runner_target(),
    ) {
        let mut full_runners = Vec::new();
        for runner in &runners {
            full_runners.push(Runner {
                slots_busy: runner.slots_total.saturating_add(extra_busy),
                ..runner.clone()
            });
        }

        prop_assert_eq!(choose_runner(&target, &full_runners), None);
    }

    #[test]
    fn test_matches_target_property_specific_runner_is_that_device(
        runners in available_runners(),
        device_id in prop_oneof![
            device_identifier(),
            Just(DeviceId("runner-0".to_owned())),
        ],
    ) {
        let target = RunnerTarget::SpecificRunner {
            device_id: device_id.clone(),
        };

        let chosen = choose_runner(&target, &runners);

        let is_listed =
            runners.iter().any(|runner| runner.device_id == device_id);
        prop_assert_eq!(chosen, is_listed.then_some(device_id));
    }

    #[test]
    fn test_matches_target_property_labels_are_a_subset_of_the_runner(
        runners in available_runners(),
        labels in vec(label(), 0..4),
    ) {
        let target = RunnerTarget::RunnerWithLabels { labels: labels.clone() };

        let chosen = choose_runner(&target, &runners);

        let any_labelled =
            runners.iter().any(|runner| has_labels(runner, &labels));
        prop_assert_eq!(chosen.is_some(), any_labelled);
        if let Some(found) = find_runner(&runners, chosen.as_ref()) {
            prop_assert!(has_labels(found, &labels));
        }
    }

    #[test]
    fn test_matches_target_property_repeated_labels_change_nothing(
        runners in vec(runner(), 0..MAXIMUM_RUNNERS),
        labels in vec(label(), 0..4),
    ) {
        let mut repeated_labels = labels.clone();
        repeated_labels.extend(labels.iter().cloned());
        let target = RunnerTarget::RunnerWithLabels { labels };
        let repeated_target = RunnerTarget::RunnerWithLabels {
            labels: repeated_labels,
        };

        let chosen = choose_runner(&target, &runners);

        prop_assert_eq!(choose_runner(&repeated_target, &runners), chosen);
    }

    #[test]
    fn test_compare_preference_property_most_free_slots_wins(
        runners in available_runners(),
    ) {
        let chosen = choose_runner(&RunnerTarget::AnyFreeRunner, &runners);

        let most_free = runners.iter().map(free_slots).max();
        let chosen_runner = find_runner(&runners, chosen.as_ref());
        let chosen_free = chosen_runner.map(free_slots);
        prop_assert_eq!(chosen_free, most_free);
    }

    #[test]
    fn test_compare_preference_property_ties_go_to_the_lowest_device_id(
        runners in vec(available_runner(), 1..MAXIMUM_RUNNERS),
    ) {
        let mut tied_runners = Vec::new();
        for runner in &runners {
            tied_runners.push(Runner {
                slots_total: 2,
                slots_busy: 1,
                ..runner.clone()
            });
        }

        let target = RunnerTarget::AnyFreeRunner;
        let chosen = choose_runner(&target, &tied_runners);

        let lowest = tied_runners.iter().map(|runner| &runner.device_id).min();
        prop_assert_eq!(chosen.as_ref(), lowest);
    }

    #[test]
    fn test_compare_preference_property_matches_a_reference_ranking(
        runners in vec(runner(), 0..MAXIMUM_RUNNERS),
    ) {
        let mut ranked_runners: Vec<&Runner> = runners
            .iter()
            .filter(|runner| runner.online && runner.accepting_new_runs)
            .filter(|runner| free_slots(runner) > 0)
            .collect();
        ranked_runners.sort_by_key(|runner| {
            (Reverse(free_slots(runner)), runner.device_id.clone())
        });

        let chosen = choose_runner(&RunnerTarget::AnyFreeRunner, &runners);

        let best = ranked_runners.first().map(|runner| &runner.device_id);
        prop_assert_eq!(chosen.as_ref(), best);
    }

    #[test]
    fn test_count_free_slots_property_busier_rivals_never_win(
        runners in available_runners(),
        extra_busy in 1..4_u32,
    ) {
        let chosen = choose_runner(&RunnerTarget::AnyFreeRunner, &runners);
        let mut busier_runners = Vec::new();
        for runner in &runners {
            let is_chosen = Some(&runner.device_id) == chosen.as_ref();
            let slots_busy = if is_chosen {
                runner.slots_busy
            } else {
                runner.slots_busy.saturating_add(extra_busy)
            };
            busier_runners.push(Runner { slots_busy, ..runner.clone() });
        }

        let target = RunnerTarget::AnyFreeRunner;
        prop_assert_eq!(choose_runner(&target, &busier_runners), chosen);
    }

    #[test]
    fn test_count_free_slots_property_one_free_slot_is_enough(
        runner in available_runner(),
        slots_total in 1..=u32::MAX,
    ) {
        let last_slot_runner = Runner {
            slots_total,
            slots_busy: slots_total - 1,
            ..runner
        };
        let expected = Some(last_slot_runner.device_id.clone());

        let runners = [last_slot_runner];

        let chosen = choose_runner(&RunnerTarget::AnyFreeRunner, &runners);
        prop_assert_eq!(chosen, expected);
    }

    #[test]
    fn test_count_free_slots_property_huge_counts_compare_exactly(
        first_total in LARGE_SLOT_COUNTS,
        first_busy in any::<u32>(),
        second_total in LARGE_SLOT_COUNTS,
        second_busy in any::<u32>(),
        template in available_runner(),
    ) {
        let first = Runner {
            device_id: DeviceId("first".to_owned()),
            slots_total: first_total,
            slots_busy: first_busy,
            ..template.clone()
        };
        let second = Runner {
            device_id: DeviceId("second".to_owned()),
            slots_total: second_total,
            slots_busy: second_busy,
            ..template
        };
        let runners = [first.clone(), second.clone()];

        let chosen = choose_runner(&RunnerTarget::AnyFreeRunner, &runners);

        let expected = if free_slots(&first) == 0 && free_slots(&second) == 0 {
            None
        } else if free_slots(&second) > free_slots(&first) {
            Some(second.device_id)
        } else {
            Some(first.device_id)
        };
        prop_assert_eq!(chosen, expected);
    }
}
