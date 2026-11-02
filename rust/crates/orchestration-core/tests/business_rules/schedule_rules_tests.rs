use chrono::{DateTime, Datelike, TimeDelta, Timelike, Utc, Weekday};
use orchestration_core::schedule_rules::{
    ScheduleProblem, describe_schedule, next_run_after,
};
use orchestration_core::task::{Schedule, TimeOfDay};
use proptest::prelude::*;

use crate::entity_strategies::{
    HOURS_PER_DAY, MINUTES_PER_HOUR, any_supported_timestamp,
    arbitrary_schedule, ordinary_timestamp, valid_schedule,
};
const SAFETY_MARGIN_DAYS: i64 = 8;

fn period_of(schedule: &Schedule) -> TimeDelta {
    match schedule {
        Schedule::Hour { .. } => TimeDelta::hours(1),
        Schedule::Day { .. } => TimeDelta::days(1),
        Schedule::Week { .. } => TimeDelta::weeks(1),
    }
}

fn is_valid_time(at: TimeOfDay) -> bool {
    at.hour < HOURS_PER_DAY && at.minute < MINUTES_PER_HOUR
}

fn is_valid_schedule(schedule: &Schedule) -> bool {
    match *schedule {
        Schedule::Hour { minute } => minute < MINUTES_PER_HOUR,
        Schedule::Day { at } | Schedule::Week { at, .. } => is_valid_time(at),
    }
}

fn is_far_from_the_latest_time(after: DateTime<Utc>) -> bool {
    let margin = TimeDelta::days(SAFETY_MARGIN_DAYS);
    after < DateTime::<Utc>::MAX_UTC - margin
}

#[test]
fn test_describe_schedule_uses_the_design_wording() {
    let two_in_the_morning = TimeOfDay { hour: 2, minute: 0 };
    let nine_in_the_morning = TimeOfDay { hour: 9, minute: 0 };

    let daily = describe_schedule(&Schedule::Day {
        at: two_in_the_morning,
    });
    let weekly = describe_schedule(&Schedule::Week {
        on: Weekday::Mon,
        at: nine_in_the_morning,
    });
    let hourly = describe_schedule(&Schedule::Hour { minute: 15 });

    assert_eq!(daily, "Every day at 02:00");
    assert_eq!(weekly, "Every Monday at 09:00");
    assert_eq!(hourly, "Every hour at :15");
}

proptest! {
    #[test]
    fn test_next_run_after_property_is_later_by_at_most_one_period(
        schedule in valid_schedule(),
        after in ordinary_timestamp(),
    ) {
        let next_run = next_run_after(&schedule, after);

        prop_assert!(matches!(next_run, Ok(time) if time > after));
        if let Ok(time) = next_run {
            prop_assert!(time - after <= period_of(&schedule));
        }
    }

    #[test]
    fn test_next_run_after_property_lands_on_the_scheduled_time(
        schedule in valid_schedule(),
        after in ordinary_timestamp(),
    ) {
        let next_run = next_run_after(&schedule, after);

        prop_assert!(next_run.is_ok());
        if let Ok(time) = next_run {
            prop_assert_eq!(time.second(), 0);
            prop_assert_eq!(time.nanosecond(), 0);
            match schedule {
                Schedule::Hour { minute } => {
                    prop_assert_eq!(time.minute(), minute);
                }
                Schedule::Day { at } => {
                    prop_assert_eq!(time.hour(), at.hour);
                    prop_assert_eq!(time.minute(), at.minute);
                }
                Schedule::Week { on, at } => {
                    prop_assert_eq!(time.weekday(), on);
                    prop_assert_eq!(time.hour(), at.hour);
                    prop_assert_eq!(time.minute(), at.minute);
                }
            }
        }
    }

    #[test]
    fn test_next_run_after_property_runs_repeat_one_period_apart(
        schedule in valid_schedule(),
        after in ordinary_timestamp(),
    ) {
        let first_run = next_run_after(&schedule, after);
        prop_assert!(first_run.is_ok());

        if let Ok(first_time) = first_run {
            let second_run = next_run_after(&schedule, first_time);
            let expected = first_time + period_of(&schedule);
            prop_assert_eq!(second_run, Ok(expected));
        }
    }

    #[test]
    fn test_next_run_after_fuzz_arbitrary_input_gives_run_or_problem(
        schedule in arbitrary_schedule(),
        after in any_supported_timestamp(),
    ) {
        let next_run = next_run_after(&schedule, after);

        match next_run {
            Ok(time) => {
                prop_assert!(is_valid_schedule(&schedule));
                prop_assert!(time > after);
            }
            Err(ScheduleProblem::OutOfRange) => {
                prop_assert!(!is_far_from_the_latest_time(after));
            }
            Err(_) => prop_assert!(!is_valid_schedule(&schedule)),
        }
    }

    #[test]
    fn test_describe_schedule_property_different_schedules_read_differently(
        first in valid_schedule(),
        second in valid_schedule(),
    ) {
        let first_description = describe_schedule(&first);
        let second_description = describe_schedule(&second);

        let are_same_schedule = first == second;
        let read_the_same = first_description == second_description;
        prop_assert_eq!(are_same_schedule, read_the_same);
    }

    #[test]
    fn test_describe_schedule_property_ends_with_the_padded_time(
        schedule in valid_schedule(),
    ) {
        let description = describe_schedule(&schedule);

        let expected_ending = match schedule {
            Schedule::Hour { minute } => format!(" at :{minute:02}"),
            Schedule::Day { at } | Schedule::Week { at, .. } => {
                format!(" at {:02}:{:02}", at.hour, at.minute)
            }
        };
        prop_assert!(description.starts_with("Every "));
        prop_assert!(description.ends_with(&expected_ending));
    }

    #[test]
    fn test_describe_schedule_fuzz_arbitrary_schedules_still_read(
        schedule in arbitrary_schedule(),
    ) {
        let description = describe_schedule(&schedule);

        prop_assert!(description.starts_with("Every "));
        prop_assert!(description.contains(" at "));
    }
}
