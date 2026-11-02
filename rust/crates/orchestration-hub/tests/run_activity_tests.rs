use orchestration_hub::run_activity::{RunActivity, SleepPrevention};
use orchestration_hub::slots::SlotError;
use proptest::prelude::*;

#[derive(Clone, Copy, Debug)]
enum RunChange {
    Start,
    Finish,
}

fn any_run_change() -> impl Strategy<Value = RunChange> {
    prop_oneof![Just(RunChange::Start), Just(RunChange::Finish)]
}

fn is_sleep_prevention_settled(activity: &RunActivity) -> bool {
    let has_active_runs = activity.slots().busy_slots() > 0;
    let is_not_needed =
        matches!(activity.sleep_prevention(), SleepPrevention::NotNeeded);
    has_active_runs != is_not_needed
}

#[cfg(target_os = "macos")]
#[test]
fn test_start_run_property_keeps_a_mac_awake_while_runs_are_active() {
    let mut activity = RunActivity::new(1);

    let started = activity.start_run();

    assert!(started.is_ok());
    assert!(matches!(
        activity.sleep_prevention(),
        SleepPrevention::Held(_),
    ));
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(32))]

    #[test]
    fn test_new_property_starts_idle_without_keeping_awake(
        capacity in 0_u32..8,
    ) {
        let activity = RunActivity::new(capacity);

        prop_assert_eq!(activity.slots().capacity(), capacity);
        prop_assert_eq!(activity.slots().busy_slots(), 0);
        prop_assert!(matches!(
            activity.sleep_prevention(),
            SleepPrevention::NotNeeded,
        ));
    }

    #[test]
    fn test_start_run_property_sleep_is_handled_exactly_while_runs_are_active(
        capacity in 0_u32..4,
        changes in proptest::collection::vec(any_run_change(), 0..12),
    ) {
        let mut activity = RunActivity::new(capacity);
        for change in changes {
            let busy_before = activity.slots().busy_slots();
            let outcome = match change {
                RunChange::Start => activity.start_run(),
                RunChange::Finish => activity.finish_run(),
            };
            let busy_after = activity.slots().busy_slots();
            let has_busy_count_changed = busy_before != busy_after;

            prop_assert_eq!(has_busy_count_changed, outcome.is_ok());
            prop_assert!(busy_after <= capacity);
            prop_assert!(is_sleep_prevention_settled(&activity));
        }
    }

    #[test]
    fn test_start_run_property_starts_whenever_a_slot_is_free(
        capacity in 1_u32..4,
    ) {
        let mut activity = RunActivity::new(capacity);
        for started_runs in 1..=capacity {
            let started = activity.start_run();

            prop_assert!(started.is_ok());
            prop_assert_eq!(activity.slots().busy_slots(), started_runs);
        }
    }

    #[test]
    fn test_finish_run_property_without_an_active_run_fails(
        capacity in 0_u32..8,
    ) {
        let mut activity = RunActivity::new(capacity);

        let finished = activity.finish_run();

        prop_assert_eq!(finished, Err(SlotError::NoBusySlot));
        prop_assert!(matches!(
            activity.sleep_prevention(),
            SleepPrevention::NotNeeded,
        ));
    }

    #[test]
    fn test_start_run_property_full_runner_refuses_new_runs(
        capacity in 0_u32..4,
    ) {
        let mut activity = RunActivity::new(capacity);
        for _ in 0..capacity {
            activity
                .start_run()
                .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
        }

        let started = activity.start_run();

        prop_assert_eq!(started, Err(SlotError::NoFreeSlot));
        prop_assert_eq!(activity.slots().busy_slots(), capacity);
    }
}
