use chrono::{DateTime, Datelike, NaiveTime, TimeDelta, Timelike, Utc};
use orchestration_core::schedule_rules::{ScheduleProblem, next_run_after};
use orchestration_core::task::{Schedule, TimeOfDay};
use proptest::prelude::*;

use crate::entity_strategies::{
    HOURS_PER_DAY, MINUTES_PER_HOUR, ordinary_timestamp, valid_schedule,
    valid_time_of_day, weekday,
};

fn on_the_slot(after: DateTime<Utc>, hour: u32, minute: u32) -> DateTime<Utc> {
    let time = NaiveTime::from_hms_opt(hour, minute, 0).unwrap_or_default();
    after.date_naive().and_time(time).and_utc()
}

fn invalid_time_of_day() -> impl Strategy<Value = TimeOfDay> {
    prop_oneof![
        (HOURS_PER_DAY.., any::<u32>()),
        (0..HOURS_PER_DAY, MINUTES_PER_HOUR..),
    ]
    .prop_map(|(hour, minute)| TimeOfDay { hour, minute })
}

fn first_run(
    schedule: &Schedule,
    after: DateTime<Utc>,
) -> Result<DateTime<Utc>, TestCaseError> {
    next_run_after(schedule, after)
        .map_err(|problem| TestCaseError::fail(problem.to_string()))
}

fn invalid_time_problem(at: TimeOfDay) -> ScheduleProblem {
    ScheduleProblem::InvalidTimeOfDay {
        hour: at.hour,
        minute: at.minute,
    }
}

proptest! {
    #[test]
    fn test_next_hourly_run_property_a_run_on_the_slot_waits_an_hour(
        after in ordinary_timestamp(),
        minute in 0..MINUTES_PER_HOUR,
    ) {
        let slot = on_the_slot(after, after.hour(), minute);

        let next = first_run(&Schedule::Hour { minute }, slot)?;

        prop_assert_eq!(next, slot + TimeDelta::hours(1));
    }

    #[test]
    fn test_next_hourly_run_property_rejects_minutes_past_the_hour(
        after in ordinary_timestamp(),
        minute in MINUTES_PER_HOUR..,
    ) {
        let next = next_run_after(&Schedule::Hour { minute }, after);

        let expected = Err(ScheduleProblem::InvalidMinute { minute });
        prop_assert_eq!(&next, &expected);
        let message = next.err().map(|problem| problem.to_string());
        let minute_text = minute.to_string();
        prop_assert!(message.unwrap_or_default().contains(&minute_text));
    }

    #[test]
    fn test_next_hourly_run_property_never_skips_a_slot(
        after in ordinary_timestamp(),
        minute in 0..MINUTES_PER_HOUR,
    ) {
        let next = first_run(&Schedule::Hour { minute }, after)?;

        prop_assert!(next - TimeDelta::hours(1) <= after);
    }

    #[test]
    fn test_next_daily_run_property_a_run_on_the_slot_waits_a_day(
        after in ordinary_timestamp(),
        at in valid_time_of_day(),
    ) {
        let slot = on_the_slot(after, at.hour, at.minute);

        let next = first_run(&Schedule::Day { at }, slot)?;

        prop_assert_eq!(next, slot + TimeDelta::days(1));
    }

    #[test]
    fn test_next_daily_run_property_rejects_impossible_times(
        after in ordinary_timestamp(),
        at in invalid_time_of_day(),
    ) {
        let next = next_run_after(&Schedule::Day { at }, after);

        prop_assert_eq!(next, Err(invalid_time_problem(at)));
    }

    #[test]
    fn test_next_daily_run_property_never_skips_a_slot(
        after in ordinary_timestamp(),
        at in valid_time_of_day(),
    ) {
        let next = first_run(&Schedule::Day { at }, after)?;

        prop_assert!(next - TimeDelta::days(1) <= after);
    }

    #[test]
    fn test_next_weekly_run_property_a_run_on_the_slot_waits_a_week(
        after in ordinary_timestamp(),
        at in valid_time_of_day(),
    ) {
        let slot = on_the_slot(after, at.hour, at.minute);
        let schedule = Schedule::Week { on: slot.weekday(), at };

        let next = first_run(&schedule, slot)?;

        prop_assert_eq!(next, slot + TimeDelta::weeks(1));
    }

    #[test]
    fn test_next_weekly_run_property_rejects_impossible_times(
        after in ordinary_timestamp(),
        on in weekday(),
        at in invalid_time_of_day(),
    ) {
        let next = next_run_after(&Schedule::Week { on, at }, after);

        prop_assert_eq!(next, Err(invalid_time_problem(at)));
    }

    #[test]
    fn test_next_weekly_run_property_never_skips_a_slot(
        after in ordinary_timestamp(),
        on in weekday(),
        at in valid_time_of_day(),
    ) {
        let next = first_run(&Schedule::Week { on, at }, after)?;

        prop_assert!(next - TimeDelta::weeks(1) <= after);
        prop_assert_eq!(next.weekday(), on);
    }

    #[test]
    fn test_combine_date_and_time_property_a_later_time_runs_the_same_day(
        after in ordinary_timestamp(),
        at in valid_time_of_day(),
    ) {
        let slot = on_the_slot(after, at.hour, at.minute);
        prop_assume!(slot > after);
        let same_weekday = Schedule::Week { on: after.weekday(), at };

        let daily = first_run(&Schedule::Day { at }, after)?;
        let weekly = first_run(&same_weekday, after)?;

        prop_assert_eq!(daily, slot);
        prop_assert_eq!(weekly, slot);
    }

    #[test]
    fn test_combine_date_and_time_property_runs_at_the_whole_minute(
        after in ordinary_timestamp(),
        schedule in valid_schedule(),
    ) {
        let next = first_run(&schedule, after)?;

        let start_of_minute = next.with_second(0).and_then(|moment| {
            moment.with_nanosecond(0)
        });
        prop_assert_eq!(start_of_minute, Some(next));
    }

    #[test]
    fn test_combine_date_and_time_property_problem_names_the_given_time(
        at in invalid_time_of_day(),
    ) {
        let message = invalid_time_problem(at).to_string();

        let padded_time = format!("{:02}:{:02}", at.hour, at.minute);
        prop_assert!(message.starts_with(&padded_time), "{}", message);
    }

    #[test]
    fn test_move_past_property_the_latest_moment_has_no_next_run(
        schedule in valid_schedule(),
    ) {
        let next = next_run_after(&schedule, DateTime::<Utc>::MAX_UTC);

        prop_assert_eq!(next, Err(ScheduleProblem::OutOfRange));
    }

    #[test]
    fn test_move_past_property_just_before_the_run_finds_the_same_run(
        after in ordinary_timestamp(),
        schedule in valid_schedule(),
    ) {
        let next = first_run(&schedule, after)?;
        let just_before = next - TimeDelta::nanoseconds(1);

        prop_assert_eq!(first_run(&schedule, just_before)?, next);
    }

    #[test]
    fn test_move_past_property_a_later_moment_never_runs_earlier(
        first_moment in ordinary_timestamp(),
        second_moment in ordinary_timestamp(),
        schedule in valid_schedule(),
    ) {
        let earlier = first_moment.min(second_moment);
        let later = first_moment.max(second_moment);

        let earlier_run = first_run(&schedule, earlier)?;
        let later_run = first_run(&schedule, later)?;

        prop_assert!(earlier_run <= later_run);
    }
}
