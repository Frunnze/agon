use std::process::Command;
use std::sync::{Mutex, PoisonError};

use orchestration_hub::keep_awake::{KeepAwakeError, KeepAwakeGuard};
use proptest::prelude::*;
use proptest::sample::Index;

use crate::target_folders::fail_with;

const KEEP_AWAKE_CASES: u32 = 4;
const LARGEST_GUARD_COUNT: usize = 4;
const POWER_SETTINGS_PROGRAM: &str = "/usr/bin/pmset";
const KEEP_AWAKE_REASON: &str = "Agent runs are in progress";
const IDLE_SLEEP_ASSERTION: &str = "PreventUserIdleSystemSleep";
const GUARD_DESCRIPTION: &str = "KeepAwakeGuard { .. }";
const ERROR_SENTENCE: &str = "could not keep the computer awake: ";

static POWER_ASSERTIONS: Mutex<()> = Mutex::new(());

fn list_own_assertions() -> Result<Vec<String>, TestCaseError> {
    let output = Command::new(POWER_SETTINGS_PROGRAM)
        .args(["-g", "assertions"])
        .output()
        .map_err(|problem| fail_with(&problem))?;
    let listing = String::from_utf8_lossy(&output.stdout);
    let owner = format!("pid {}(", std::process::id());
    let mut own_assertions = Vec::new();
    for line in listing.lines() {
        let is_ours = line.trim_start().starts_with(&owner);
        if is_ours && line.contains(KEEP_AWAKE_REASON) {
            own_assertions.push(line.to_owned());
        }
    }
    Ok(own_assertions)
}

fn acquire_guards(count: usize) -> Result<Vec<KeepAwakeGuard>, TestCaseError> {
    let mut guards = Vec::new();
    for _ in 0..count {
        guards.push(
            KeepAwakeGuard::acquire()
                .map_err(|problem| fail_with(&problem))?,
        );
    }
    Ok(guards)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(KEEP_AWAKE_CASES))]

    #[test]
    fn test_acquire_property_holds_one_assertion_per_guard(
        guard_count in 1..=LARGEST_GUARD_COUNT,
    ) {
        let _serialized = POWER_ASSERTIONS
            .lock()
            .unwrap_or_else(PoisonError::into_inner);

        let guards = acquire_guards(guard_count)?;
        let held = list_own_assertions()?;
        drop(guards);
        let released = list_own_assertions()?;

        prop_assert_eq!(held.len(), guard_count);
        prop_assert_eq!(released.len(), 0);
    }

    #[test]
    fn test_acquire_property_releases_in_any_drop_order(
        guard_count in 1..=LARGEST_GUARD_COUNT,
        drop_choices in proptest::collection::vec(any::<Index>(), 4),
    ) {
        let _serialized = POWER_ASSERTIONS
            .lock()
            .unwrap_or_else(PoisonError::into_inner);
        let mut guards = acquire_guards(guard_count)?;

        for choice in drop_choices.iter().take(guard_count) {
            let held_before = guards.len();
            let dropped = guards.remove(choice.index(guards.len()));
            drop(dropped);
            prop_assert_eq!(list_own_assertions()?.len(), held_before - 1);
        }
    }

    #[test]
    fn test_acquire_property_asks_to_stay_awake_while_idle(
        guard_count in 1..=LARGEST_GUARD_COUNT,
    ) {
        let _serialized = POWER_ASSERTIONS
            .lock()
            .unwrap_or_else(PoisonError::into_inner);

        let guards = acquire_guards(guard_count)?;
        let held = list_own_assertions()?;
        drop(guards);

        for assertion in held {
            let is_idle_sleep = assertion.contains(IDLE_SLEEP_ASSERTION);
            prop_assert!(is_idle_sleep, "{assertion}");
        }
    }

    #[test]
    fn test_keep_awake_guard_fmt_property_hides_its_insides(
        guard_count in 1..=LARGEST_GUARD_COUNT,
    ) {
        let _serialized = POWER_ASSERTIONS
            .lock()
            .unwrap_or_else(PoisonError::into_inner);
        let guards = acquire_guards(guard_count)?;

        for guard in &guards {
            prop_assert_eq!(format!("{guard:?}"), GUARD_DESCRIPTION);
        }
    }

    #[test]
    fn test_keep_awake_guard_fmt_property_never_names_the_reason(
        guard_count in 1..=LARGEST_GUARD_COUNT,
    ) {
        let _serialized = POWER_ASSERTIONS
            .lock()
            .unwrap_or_else(PoisonError::into_inner);
        let guards = acquire_guards(guard_count)?;

        for guard in &guards {
            let pretty = format!("{guard:#?}");
            prop_assert!(!pretty.contains(KEEP_AWAKE_REASON));
            prop_assert!(pretty.starts_with("KeepAwakeGuard"));
        }
    }

    #[test]
    fn test_keep_awake_guard_fmt_property_is_the_same_for_every_guard(
        guard_count in 2..=LARGEST_GUARD_COUNT,
    ) {
        let _serialized = POWER_ASSERTIONS
            .lock()
            .unwrap_or_else(PoisonError::into_inner);
        let guards = acquire_guards(guard_count)?;

        let first = format!("{:?}", guards[0]);
        for guard in &guards {
            let described = format!("{guard:?}");
            prop_assert_eq!(&described, &first);
        }
    }

    #[test]
    fn test_keep_awake_error_fmt_property_names_the_reason(
        reason in any::<String>(),
    ) {
        let error = KeepAwakeError::Unavailable(reason.clone());

        let expected = format!("{ERROR_SENTENCE}{reason}");
        prop_assert_eq!(error.to_string(), expected);
    }

    #[test]
    fn test_keep_awake_error_fmt_property_distinct_reasons_stay_apart(
        first_reason in any::<String>(),
        second_reason in any::<String>(),
    ) {
        let first = KeepAwakeError::Unavailable(first_reason.clone());
        let second = KeepAwakeError::Unavailable(second_reason.clone());

        let messages_match = first.to_string() == second.to_string();
        prop_assert_eq!(messages_match, first_reason == second_reason);
    }

    #[test]
    fn test_keep_awake_error_fmt_property_debug_names_the_variant(
        reason in "[a-zA-Z0-9 ]{0,30}",
    ) {
        let error = KeepAwakeError::Unavailable(reason.clone());

        let debugged = format!("{error:?}");
        prop_assert!(debugged.starts_with("Unavailable("));
        prop_assert!(debugged.contains(&reason));
    }
}
