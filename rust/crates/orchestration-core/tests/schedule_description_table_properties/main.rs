use chrono::Weekday;
use orchestration_core::schedule_rules::describe_schedule;
use orchestration_core::task::{Schedule, TimeOfDay};
use proptest::prelude::*;
use serde::Deserialize;

const SHARED_SCHEDULE_TABLE: &str =
    include_str!("../fixtures/schedule_model_cases.json");
const NIGHT_ENDS_BEFORE_HOUR: u32 = 6;
const HOURS_PER_DAY: u32 = 24;
const MINUTES_PER_HOUR: u32 = 60;
const NIGHT_WORD: &str = "night";
const ALL_WEEKDAYS: [Weekday; 7] = [
    Weekday::Mon,
    Weekday::Tue,
    Weekday::Wed,
    Weekday::Thu,
    Weekday::Fri,
    Weekday::Sat,
    Weekday::Sun,
];

#[derive(Debug, Deserialize)]
struct SharedDescriptionTable {
    schedule_descriptions: Vec<SharedScheduleDescription>,
}

#[derive(Debug, Deserialize)]
struct SharedScheduleDescription {
    schedule: Schedule,
    description: String,
}

fn read_shared_descriptions()
-> Result<Vec<SharedScheduleDescription>, serde_json::Error> {
    let table: SharedDescriptionTable =
        serde_json::from_str(SHARED_SCHEDULE_TABLE)?;
    Ok(table.schedule_descriptions)
}

fn time_of_day() -> impl Strategy<Value = TimeOfDay> {
    (0..HOURS_PER_DAY, 0..MINUTES_PER_HOUR)
        .prop_map(|(hour, minute)| TimeOfDay { hour, minute })
}

fn weekday() -> impl Strategy<Value = Weekday> {
    proptest::sample::select(ALL_WEEKDAYS.to_vec())
}

fn padded_time(at: TimeOfDay) -> String {
    format!("{:02}:{:02}", at.hour, at.minute)
}

#[test]
fn test_describe_schedule_property_matches_the_shared_description_table()
-> Result<(), serde_json::Error> {
    let cases = read_shared_descriptions()?;

    assert!(!cases.is_empty());
    for case in cases {
        assert_eq!(
            describe_schedule(&case.schedule),
            case.description,
            "{case:?}"
        );
    }
    Ok(())
}

proptest! {
    #[test]
    fn test_describe_schedule_property_daily_before_six_reads_as_night(
        at in time_of_day(),
    ) {
        let description = describe_schedule(&Schedule::Day { at });

        let period = if at.hour < NIGHT_ENDS_BEFORE_HOUR {
            NIGHT_WORD
        } else {
            "day"
        };
        let expected = format!("Every {period} at {}", padded_time(at));
        prop_assert_eq!(description, expected);
    }

    #[test]
    fn test_describe_schedule_property_weekly_never_reads_as_night(
        on in weekday(),
        at in time_of_day(),
    ) {
        let description = describe_schedule(&Schedule::Week { on, at });

        prop_assert!(!description.contains(NIGHT_WORD), "{}", description);
        prop_assert!(description.starts_with("Every "), "{}", description);
        prop_assert!(
            description.ends_with(&padded_time(at)),
            "{}",
            description
        );
    }

    #[test]
    fn test_describe_schedule_property_daily_and_weekly_show_the_same_time(
        on in weekday(),
        at in time_of_day(),
    ) {
        let daily = describe_schedule(&Schedule::Day { at });
        let weekly = describe_schedule(&Schedule::Week { on, at });

        let daily_time = daily.rsplit(' ').next().unwrap_or_default();
        let weekly_time = weekly.rsplit(' ').next().unwrap_or_default();
        prop_assert_eq!(daily_time, weekly_time);
        prop_assert_ne!(daily, weekly);
    }
}
