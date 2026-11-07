use std::collections::BTreeSet;

use chrono::Weekday;
use orchestration_core::schedule_rules::describe_schedule;
use orchestration_core::task::{Schedule, TimeOfDay};
use proptest::prelude::*;

use crate::entity_strategies::{valid_schedule, valid_time_of_day, weekday};

const DAILY_PREFIX: &str = "Every day at ";
const WEEKLY_PREFIX: &str = "Every ";
const TIME_SEPARATOR: char = ':';
const PADDED_TIME_LENGTH: usize = 5;
const DAY_WORD: &str = "day";
const ALL_WEEKDAYS: [Weekday; 7] = [
    Weekday::Mon,
    Weekday::Tue,
    Weekday::Wed,
    Weekday::Thu,
    Weekday::Fri,
    Weekday::Sat,
    Weekday::Sun,
];

fn described_time(at: TimeOfDay) -> String {
    let description = describe_schedule(&Schedule::Day { at });
    let time = description.strip_prefix(DAILY_PREFIX).unwrap_or_default();
    time.to_owned()
}

fn weekday_name(on: Weekday, at: TimeOfDay) -> String {
    let description = describe_schedule(&Schedule::Week { on, at });
    let without_prefix =
        description.strip_prefix(WEEKLY_PREFIX).unwrap_or_default();
    let name = without_prefix.split(' ').next().unwrap_or_default();
    name.to_owned()
}

fn names_a_weekday(description: &str, at: TimeOfDay) -> bool {
    ALL_WEEKDAYS
        .iter()
        .any(|day| description.contains(&weekday_name(*day, at)))
}

proptest! {
    #[test]
    fn test_describe_schedule_property_only_weekly_names_a_weekday(
        schedule in valid_schedule(),
    ) {
        let description = describe_schedule(&schedule);

        let any_time = TimeOfDay { hour: 0, minute: 0 };
        let is_weekly = matches!(schedule, Schedule::Week { .. });
        prop_assert_eq!(names_a_weekday(&description, any_time), is_weekly);
    }

    #[test]
    fn test_describe_time_of_day_property_reads_back_the_time(
        at in valid_time_of_day(),
    ) {
        let time = described_time(at);

        let (hour_text, minute_text) = time
            .split_once(TIME_SEPARATOR)
            .ok_or_else(|| TestCaseError::fail(time.clone()))?;
        prop_assert_eq!(hour_text.parse::<u32>().ok(), Some(at.hour));
        prop_assert_eq!(minute_text.parse::<u32>().ok(), Some(at.minute));
    }

    #[test]
    fn test_describe_time_of_day_property_pads_to_five_characters(
        at in valid_time_of_day(),
    ) {
        let time = described_time(at);

        prop_assert_eq!(time.len(), PADDED_TIME_LENGTH);
        prop_assert_eq!(time.chars().nth(2), Some(TIME_SEPARATOR));
    }

    #[test]
    fn test_describe_time_of_day_property_sorts_like_the_clock(
        first in valid_time_of_day(),
        second in valid_time_of_day(),
    ) {
        let first_key = (first.hour, first.minute);
        let second_key = (second.hour, second.minute);

        prop_assert_eq!(
            described_time(first).cmp(&described_time(second)),
            first_key.cmp(&second_key)
        );
    }

    #[test]
    fn test_name_weekday_property_reads_back_as_the_same_weekday(
        on in weekday(),
        at in valid_time_of_day(),
    ) {
        let name = weekday_name(on, at);

        prop_assert_eq!(name.parse::<Weekday>().ok(), Some(on));
    }

    #[test]
    fn test_name_weekday_property_gives_each_day_its_own_name(
        at in valid_time_of_day(),
    ) {
        let mut names: BTreeSet<String> = BTreeSet::new();
        for day in ALL_WEEKDAYS {
            let name = weekday_name(day, at);
            let starts_upper =
                name.chars().next().is_some_and(char::is_uppercase);
            prop_assert!(starts_upper, "{}", name);
            prop_assert!(name.ends_with(DAY_WORD), "{}", name);
            names.insert(name);
        }

        prop_assert_eq!(names.len(), ALL_WEEKDAYS.len());
    }

    #[test]
    fn test_name_weekday_property_weekly_reads_like_daily_with_the_day(
        on in weekday(),
        at in valid_time_of_day(),
    ) {
        let weekly = describe_schedule(&Schedule::Week { on, at });
        let daily = describe_schedule(&Schedule::Day { at });

        let name = weekday_name(on, at);
        let weekly_as_daily = weekly.replacen(&name, DAY_WORD, 1);
        prop_assert_eq!(weekly_as_daily, daily);
    }
}
