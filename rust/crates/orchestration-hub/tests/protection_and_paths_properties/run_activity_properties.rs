use orchestration_hub::run_activity::{RunActivity, SleepPrevention};
use orchestration_hub::slots::SlotError;
use proptest::prelude::*;

use crate::hook_running::to_case_error;

const ACTIVITY_CASES: u32 = 24;

#[derive(Clone, Copy, Debug)]
enum RunChange {
    Start,
    Finish,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum PreventionShape {
    NotNeeded,
    Held,
    Unavailable,
}

fn any_run_changes() -> impl Strategy<Value = Vec<RunChange>> {
    let change = prop_oneof![Just(RunChange::Start), Just(RunChange::Finish)];
    proptest::collection::vec(change, 0..16)
}

fn shape_of(activity: &RunActivity) -> PreventionShape {
    match activity.sleep_prevention() {
        SleepPrevention::NotNeeded => PreventionShape::NotNeeded,
        SleepPrevention::Held(_) => PreventionShape::Held,
        SleepPrevention::Unavailable(_) => PreventionShape::Unavailable,
    }
}

fn apply_change(
    activity: &mut RunActivity,
    change: RunChange,
) -> Result<(), SlotError> {
    match change {
        RunChange::Start => activity.start_run(),
        RunChange::Finish => activity.finish_run(),
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(ACTIVITY_CASES))]

    #[test]
    fn test_run_activity_new_property_keeps_the_capacity(
        capacity in any::<u32>(),
    ) {
        let activity = RunActivity::new(capacity);

        prop_assert_eq!(activity.slots().capacity(), capacity);
        prop_assert_eq!(activity.slots().busy_slots(), 0);
    }

    #[test]
    fn test_run_activity_new_property_starts_without_keeping_awake(
        capacity in any::<u32>(),
    ) {
        let activity = RunActivity::new(capacity);

        prop_assert_eq!(shape_of(&activity), PreventionShape::NotNeeded);
    }

    #[test]
    fn test_run_activity_new_property_nothing_to_finish_at_first(
        capacity in 0_u32..64,
    ) {
        let mut activity = RunActivity::new(capacity);

        let finished = activity.finish_run();

        prop_assert_eq!(finished, Err(SlotError::NoBusySlot));
        prop_assert_eq!(activity.slots().busy_slots(), 0);
    }

    #[test]
    fn test_start_run_property_follows_a_slot_model(
        capacity in 0_u32..5,
        changes in any_run_changes(),
    ) {
        let mut activity = RunActivity::new(capacity);
        let mut model_busy = 0_u32;

        for change in changes {
            let outcome = apply_change(&mut activity, change);
            let expected = match change {
                RunChange::Start if model_busy < capacity => Ok(()),
                RunChange::Start => Err(SlotError::NoFreeSlot),
                RunChange::Finish if model_busy > 0 => Ok(()),
                RunChange::Finish => Err(SlotError::NoBusySlot),
            };
            if expected.is_ok() {
                model_busy = match change {
                    RunChange::Start => model_busy + 1,
                    RunChange::Finish => model_busy - 1,
                };
            }
            prop_assert_eq!(outcome, expected);
            prop_assert_eq!(activity.slots().busy_slots(), model_busy);
        }
    }

    #[test]
    fn test_finish_run_property_undoes_a_start(
        capacity in 1_u32..5,
        changes in any_run_changes(),
    ) {
        let mut activity = RunActivity::new(capacity);
        for change in changes {
            let _outcome = apply_change(&mut activity, change);
        }
        let before = activity.slots();
        prop_assume!(before.busy_slots() < capacity);

        activity.start_run().map_err(to_case_error)?;
        activity.finish_run().map_err(to_case_error)?;

        prop_assert_eq!(activity.slots(), before);
    }

    #[test]
    fn test_finish_run_property_last_finish_lets_the_computer_sleep(
        capacity in 1_u32..5,
        runs in 1_u32..5,
    ) {
        let mut activity = RunActivity::new(capacity);
        let started = runs.min(capacity);
        for _ in 0..started {
            activity.start_run().map_err(to_case_error)?;
        }

        for remaining in (0..started).rev() {
            activity.finish_run().map_err(to_case_error)?;
            let shape = shape_of(&activity);
            let is_not_needed = shape == PreventionShape::NotNeeded;
            prop_assert_eq!(is_not_needed, remaining == 0);
        }
    }

    #[test]
    fn test_finish_run_property_failed_finish_changes_nothing(
        capacity in 0_u32..5,
    ) {
        let mut activity = RunActivity::new(capacity);
        let before = activity.slots();

        let finished = activity.finish_run();

        prop_assert!(finished.is_err());
        prop_assert_eq!(activity.slots(), before);
        prop_assert_eq!(shape_of(&activity), PreventionShape::NotNeeded);
    }

    #[test]
    fn test_slots_property_busy_never_passes_capacity(
        capacity in 0_u32..5,
        changes in any_run_changes(),
    ) {
        let mut activity = RunActivity::new(capacity);

        for change in changes {
            let _outcome = apply_change(&mut activity, change);
            prop_assert!(activity.slots().busy_slots() <= capacity);
            prop_assert_eq!(activity.slots().capacity(), capacity);
        }
    }

    #[test]
    fn test_slots_property_reading_changes_nothing(
        capacity in 0_u32..5,
        changes in any_run_changes(),
    ) {
        let mut activity = RunActivity::new(capacity);
        for change in changes {
            let _outcome = apply_change(&mut activity, change);
        }

        let first_reading = activity.slots();
        let second_reading = activity.slots();

        prop_assert_eq!(first_reading, second_reading);
    }

    #[test]
    fn test_slots_property_full_runner_refuses_without_change(
        capacity in 0_u32..5,
    ) {
        let mut activity = RunActivity::new(capacity);
        for _ in 0..capacity {
            activity.start_run().map_err(to_case_error)?;
        }
        let before = activity.slots();
        let shape_before = shape_of(&activity);

        let started = activity.start_run();

        prop_assert_eq!(started, Err(SlotError::NoFreeSlot));
        prop_assert_eq!(activity.slots(), before);
        prop_assert_eq!(shape_of(&activity), shape_before);
    }

    #[test]
    fn test_sleep_prevention_property_needed_exactly_while_runs_are_busy(
        capacity in 0_u32..5,
        changes in any_run_changes(),
    ) {
        let mut activity = RunActivity::new(capacity);

        for change in changes {
            let _outcome = apply_change(&mut activity, change);
            let is_busy = activity.slots().busy_slots() > 0;
            let shape = shape_of(&activity);
            let is_not_needed = shape == PreventionShape::NotNeeded;
            prop_assert_eq!(is_busy, !is_not_needed);
        }
    }

    #[test]
    fn test_sleep_prevention_property_kept_while_more_runs_start(
        capacity in 2_u32..5,
    ) {
        let mut activity = RunActivity::new(capacity);
        activity.start_run().map_err(to_case_error)?;
        let first_shape = shape_of(&activity);

        for _ in 1..capacity {
            activity.start_run().map_err(to_case_error)?;
            prop_assert_eq!(shape_of(&activity), first_shape);
        }
    }

    #[test]
    fn test_sleep_prevention_property_reading_changes_nothing(
        capacity in 0_u32..5,
        changes in any_run_changes(),
    ) {
        let mut activity = RunActivity::new(capacity);
        for change in changes {
            let _outcome = apply_change(&mut activity, change);
        }

        let first_shape = shape_of(&activity);
        let second_shape = shape_of(&activity);

        prop_assert_eq!(first_shape, second_shape);
    }

    #[test]
    fn test_prevent_sleep_property_every_start_settles_the_prevention(
        capacity in 1_u32..5,
        changes in any_run_changes(),
    ) {
        let mut activity = RunActivity::new(capacity);

        for change in changes {
            let outcome = apply_change(&mut activity, change);
            if matches!(change, RunChange::Start) && outcome.is_ok() {
                let shape = shape_of(&activity);
                prop_assert_ne!(shape, PreventionShape::NotNeeded);
            }
        }
    }

    #[test]
    fn test_prevent_sleep_property_tries_again_after_an_idle_spell(
        capacity in 1_u32..5,
        rounds in 1_usize..4,
    ) {
        let mut activity = RunActivity::new(capacity);

        for _ in 0..rounds {
            activity.start_run().map_err(to_case_error)?;
            prop_assert_ne!(shape_of(&activity), PreventionShape::NotNeeded);
            activity.finish_run().map_err(to_case_error)?;
            prop_assert_eq!(shape_of(&activity), PreventionShape::NotNeeded);
        }
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn test_prevent_sleep_property_a_mac_is_kept_awake(capacity in 1_u32..5) {
        let mut activity = RunActivity::new(capacity);

        activity.start_run().map_err(to_case_error)?;

        prop_assert_eq!(shape_of(&activity), PreventionShape::Held);
    }
}
