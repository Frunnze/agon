use chrono::{DateTime, Datelike, Utc, Weekday};
use orchestration_core::agent_kind_label::describe_agent_kind;
use orchestration_core::schedule_rules::{describe_schedule, next_run_after};
use orchestration_core::task::{Schedule, TimeOfDay};
use orchestration_core::workflow::AgentKind;
use proptest::prelude::*;
use proptest::sample::Index;
use serde::Deserialize;
use serde_json::Value;

const SHARED_SCHEDULE_TABLE: &str =
    include_str!("../fixtures/schedule_model_cases.json");
const LATEST_TESTED_SECOND: i64 = 4_102_444_800;
const SAMPLE_TIME: TimeOfDay = TimeOfDay { hour: 9, minute: 5 };

#[derive(Debug, Deserialize)]
struct SharedScheduleTable {
    weekdays: Vec<SharedWeekday>,
    times_of_day: Vec<SharedTimeOfDay>,
    hourly_minutes: Vec<SharedHourlyMinute>,
    agent_kinds: Vec<SharedAgentKind>,
}

#[derive(Debug, Deserialize)]
struct SharedWeekday {
    wire_name: String,
    iso_number: u32,
    label: String,
}

#[derive(Debug, Deserialize)]
struct SharedTimeOfDay {
    hour: u32,
    minute: u32,
    is_valid: bool,
}

#[derive(Debug, Deserialize)]
struct SharedHourlyMinute {
    minute: u32,
    is_valid: bool,
}

#[derive(Debug, Deserialize)]
struct SharedAgentKind {
    wire_name: String,
    label: String,
}

fn read_shared_table() -> Result<SharedScheduleTable, serde_json::Error> {
    serde_json::from_str(SHARED_SCHEDULE_TABLE)
}

fn decode_wire_name<Choice: for<'de> Deserialize<'de>>(
    wire_name: &str,
) -> Result<Choice, serde_json::Error> {
    serde_json::from_value(Value::String(wire_name.to_owned()))
}

#[test]
fn test_weekday_wire_name_property_matches_the_shared_table()
-> Result<(), serde_json::Error> {
    let table = read_shared_table()?;
    let mut iso_numbers: Vec<u32> = Vec::new();

    for case in &table.weekdays {
        let weekday: Weekday = decode_wire_name(&case.wire_name)?;
        let written = serde_json::to_value(weekday)?;

        assert_eq!(written, Value::String(case.wire_name.clone()));
        assert_eq!(weekday.number_from_monday(), case.iso_number);
        iso_numbers.push(case.iso_number);
    }
    assert_eq!(iso_numbers, (1..=7).collect::<Vec<u32>>());
    Ok(())
}

#[test]
fn test_describe_schedule_property_names_the_shared_weekday_label()
-> Result<(), serde_json::Error> {
    for case in read_shared_table()?.weekdays {
        let on: Weekday = decode_wire_name(&case.wire_name)?;
        let schedule = Schedule::Week {
            on,
            at: SAMPLE_TIME,
        };
        let expected = format!("Every {} at 09:05", case.label);

        assert_eq!(describe_schedule(&schedule), expected);
    }
    Ok(())
}

#[test]
fn test_next_run_after_property_times_agree_with_the_shared_table()
-> Result<(), serde_json::Error> {
    let after = DateTime::UNIX_EPOCH;

    for case in read_shared_table()?.times_of_day {
        let at = TimeOfDay {
            hour: case.hour,
            minute: case.minute,
        };
        let daily = next_run_after(&Schedule::Day { at }, after);
        let weekly = next_run_after(
            &Schedule::Week {
                on: Weekday::Sun,
                at,
            },
            after,
        );

        assert_eq!(daily.is_ok(), case.is_valid, "{case:?}");
        assert_eq!(weekly.is_ok(), case.is_valid, "{case:?}");
    }
    Ok(())
}

#[test]
fn test_next_run_after_property_hourly_minutes_agree_with_shared_table()
-> Result<(), serde_json::Error> {
    let after = DateTime::UNIX_EPOCH;

    for case in read_shared_table()?.hourly_minutes {
        let schedule = Schedule::Hour {
            minute: case.minute,
        };

        let next_run = next_run_after(&schedule, after);

        assert_eq!(next_run.is_ok(), case.is_valid, "{case:?}");
    }
    Ok(())
}

#[test]
fn test_describe_agent_kind_property_matches_the_shared_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_table()?.agent_kinds {
        let kind: AgentKind = decode_wire_name(&case.wire_name)?;
        let written = serde_json::to_value(kind)?;

        assert_eq!(written, Value::String(case.wire_name.clone()));
        assert_eq!(describe_agent_kind(kind), case.label);
    }
    Ok(())
}

proptest! {
    #[test]
    fn test_next_run_after_property_runs_on_the_shared_iso_day(
        case_position in any::<Index>(),
        after_second in 0..LATEST_TESTED_SECOND,
    ) {
        let table = read_shared_table()?;
        let case = &table.weekdays[case_position.index(table.weekdays.len())];
        let on: Weekday = decode_wire_name(&case.wire_name)?;
        let after: DateTime<Utc> = DateTime::from_timestamp(after_second, 0)
            .unwrap_or(DateTime::UNIX_EPOCH);
        let schedule = Schedule::Week { on, at: SAMPLE_TIME };

        let next_run = next_run_after(&schedule, after);

        prop_assert!(next_run.is_ok());
        if let Ok(next_run) = next_run {
            prop_assert_eq!(
                next_run.weekday().number_from_monday(),
                case.iso_number
            );
            prop_assert!(next_run > after);
        }
    }
}
