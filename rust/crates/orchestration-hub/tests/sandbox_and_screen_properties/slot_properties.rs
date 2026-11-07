use orchestration_hub::slots::{SlotCounter, SlotError};
use proptest::collection::vec;
use proptest::prelude::*;

const LARGEST_SMALL_CAPACITY: u32 = 64;

fn any_capacity() -> impl Strategy<Value = u32> {
    prop_oneof![0..LARGEST_SMALL_CAPACITY, Just(u32::MAX), any::<u32>()]
}

fn take_times(
    counter: SlotCounter,
    times: u32,
) -> Result<SlotCounter, SlotError> {
    let mut taken = counter;
    for _ in 0..times {
        taken = taken.take_slot()?;
    }
    Ok(taken)
}

fn apply_changes(capacity: u32, takes: &[bool]) -> (SlotCounter, u32) {
    let mut counter = SlotCounter::new(capacity);
    let mut expected_busy: u32 = 0;
    for is_take in takes {
        let changed = if *is_take {
            counter.take_slot()
        } else {
            counter.release_slot()
        };
        if let Ok(changed_counter) = changed {
            counter = changed_counter;
            if *is_take {
                expected_busy += 1;
            } else {
                expected_busy -= 1;
            }
        }
    }
    (counter, expected_busy)
}

proptest! {
    #[test]
    fn test_slot_counter_new_property_keeps_the_exact_capacity(
        capacity in any_capacity(),
    ) {
        let counter = SlotCounter::new(capacity);

        prop_assert_eq!(counter.capacity(), capacity);
        prop_assert_eq!(counter.busy_slots(), 0);
    }

    #[test]
    fn test_slot_counter_new_property_nothing_to_release_at_first(
        capacity in any_capacity(),
    ) {
        let released = SlotCounter::new(capacity).release_slot();

        prop_assert_eq!(released, Err(SlotError::NoBusySlot));
    }

    #[test]
    fn test_slot_counter_new_property_equal_capacities_make_equal_counters(
        first in any_capacity(),
        second in any_capacity(),
    ) {
        let are_equal = SlotCounter::new(first) == SlotCounter::new(second);

        prop_assert_eq!(are_equal, first == second);
    }

    #[test]
    fn test_take_slot_property_fills_exactly_capacity_slots(
        capacity in 0..LARGEST_SMALL_CAPACITY,
    ) {
        let filled = take_times(SlotCounter::new(capacity), capacity)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert_eq!(filled.busy_slots(), capacity);
        prop_assert_eq!(filled.take_slot(), Err(SlotError::NoFreeSlot));
    }

    #[test]
    fn test_take_slot_property_leaves_the_original_counter_unchanged(
        capacity in 1..LARGEST_SMALL_CAPACITY,
        busy in 0..LARGEST_SMALL_CAPACITY,
    ) {
        let counter = take_times(SlotCounter::new(capacity), busy % capacity)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
        let before = counter;

        let taken = counter.take_slot();

        prop_assert_eq!(counter, before);
        prop_assert_eq!(
            taken.map(SlotCounter::busy_slots),
            Ok(before.busy_slots() + 1),
        );
    }

    #[test]
    fn test_release_slot_property_counts_down_to_zero(
        capacity in 0..LARGEST_SMALL_CAPACITY,
    ) {
        let mut counter = take_times(SlotCounter::new(capacity), capacity)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        for expected_busy in (0..capacity).rev() {
            counter = counter
                .release_slot()
                .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
            prop_assert_eq!(counter.busy_slots(), expected_busy);
        }
        prop_assert_eq!(counter.release_slot(), Err(SlotError::NoBusySlot));
    }

    #[test]
    fn test_release_slot_property_frees_a_slot_for_the_next_take(
        capacity in 1..LARGEST_SMALL_CAPACITY,
    ) {
        let full = take_times(SlotCounter::new(capacity), capacity)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        let reused = full.release_slot().and_then(SlotCounter::take_slot);

        prop_assert_eq!(reused, Ok(full));
    }

    #[test]
    fn test_capacity_property_survives_any_change_sequence(
        capacity in 0_u32..6,
        takes in vec(any::<bool>(), 0..40),
    ) {
        let (counter, _expected_busy) = apply_changes(capacity, &takes);

        prop_assert_eq!(counter.capacity(), capacity);
    }

    #[test]
    fn test_capacity_property_huge_capacities_still_take_slots(
        capacity in (u32::MAX - 8)..=u32::MAX,
        takes in 0_u32..8,
    ) {
        let counter = take_times(SlotCounter::new(capacity), takes)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        prop_assert_eq!(counter.capacity(), capacity);
        prop_assert_eq!(counter.busy_slots(), takes);
    }

    #[test]
    fn test_capacity_property_bounds_the_busy_slots(
        capacity in 0_u32..6,
        takes in vec(any::<bool>(), 0..40),
    ) {
        let (counter, _expected_busy) = apply_changes(capacity, &takes);

        prop_assert!(counter.busy_slots() <= counter.capacity());
    }

    #[test]
    fn test_busy_slots_property_matches_the_counting_model(
        capacity in 0_u32..6,
        takes in vec(any::<bool>(), 0..40),
    ) {
        let (counter, expected_busy) = apply_changes(capacity, &takes);

        prop_assert_eq!(counter.busy_slots(), expected_busy);
    }

    #[test]
    fn test_busy_slots_property_free_slots_never_go_negative(
        capacity in 0_u32..6,
        takes in vec(any::<bool>(), 0..40),
    ) {
        let (counter, _expected_busy) = apply_changes(capacity, &takes);

        let free_slots = counter.capacity().checked_sub(counter.busy_slots());
        prop_assert!(free_slots.is_some());
        let can_take = counter.take_slot().is_ok();
        prop_assert_eq!(can_take, free_slots != Some(0));
    }

    #[test]
    fn test_busy_slots_property_failed_changes_keep_the_count(
        capacity in 0_u32..6,
        takes in vec(any::<bool>(), 0..40),
    ) {
        let (counter, _expected_busy) = apply_changes(capacity, &takes);

        let is_full = counter.busy_slots() == counter.capacity();
        let is_idle = counter.busy_slots() == 0;
        prop_assert_eq!(counter.take_slot().is_err(), is_full);
        prop_assert_eq!(counter.release_slot().is_err(), is_idle);
    }
}
