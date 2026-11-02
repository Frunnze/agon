use orchestration_hub::slots::{SlotCounter, SlotError};
use proptest::prelude::*;

#[derive(Clone, Copy, Debug)]
enum SlotChange {
    Take,
    Release,
}

fn any_slot_change() -> impl Strategy<Value = SlotChange> {
    prop_oneof![Just(SlotChange::Take), Just(SlotChange::Release)]
}

fn any_capacity() -> impl Strategy<Value = u32> {
    prop_oneof![0_u32..8, Just(u32::MAX)]
}

proptest! {
    #[test]
    fn test_new_property_starts_with_every_slot_free(
        capacity in any_capacity(),
    ) {
        let counter = SlotCounter::new(capacity);

        prop_assert_eq!(counter.capacity(), capacity);
        prop_assert_eq!(counter.busy_slots(), 0);
    }

    #[test]
    fn test_take_slot_property_busy_slots_never_exceed_capacity(
        capacity in 0_u32..6,
        changes in proptest::collection::vec(any_slot_change(), 0..40),
    ) {
        let mut counter = SlotCounter::new(capacity);
        for change in changes {
            let busy_before = counter.busy_slots();
            let changed = match change {
                SlotChange::Take => counter.take_slot(),
                SlotChange::Release => counter.release_slot(),
            };
            let expected = match change {
                SlotChange::Take if busy_before == capacity => {
                    Err(SlotError::NoFreeSlot)
                }
                SlotChange::Release if busy_before == 0 => {
                    Err(SlotError::NoBusySlot)
                }
                SlotChange::Take => Ok(busy_before + 1),
                SlotChange::Release => Ok(busy_before - 1),
            };

            prop_assert_eq!(changed.map(SlotCounter::busy_slots), expected);
            counter = changed.unwrap_or(counter);
            prop_assert!(counter.busy_slots() <= counter.capacity());
            prop_assert_eq!(counter.capacity(), capacity);
        }
    }

    #[test]
    fn test_release_slot_property_undoes_take_slot(
        capacity in 1_u32..64,
        busy in 0_u32..64,
    ) {
        let mut counter = SlotCounter::new(capacity);
        for _ in 0..busy.min(capacity - 1) {
            counter = counter
                .take_slot()
                .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
        }

        let round_trip =
            counter.take_slot().and_then(SlotCounter::release_slot);

        prop_assert_eq!(round_trip, Ok(counter));
    }
}
