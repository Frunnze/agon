use chrono::{
    DateTime, Datelike, Days, NaiveDate, NaiveTime, TimeDelta, Timelike, Utc,
    Weekday,
};
use thiserror::Error;

use crate::task::{Schedule, TimeOfDay};

const DAYS_PER_WEEK: u32 = 7;
const NIGHT_ENDS_BEFORE_HOUR: u32 = 6;

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum ScheduleProblem {
    #[error("minute {minute} is not between 0 and 59")]
    InvalidMinute { minute: u32 },
    #[error("{hour:02}:{minute:02} is not a time of day")]
    InvalidTimeOfDay { hour: u32, minute: u32 },
    #[error("the next run falls after the latest supported time")]
    OutOfRange,
}

pub fn next_run_after(
    schedule: &Schedule,
    after: DateTime<Utc>,
) -> Result<DateTime<Utc>, ScheduleProblem> {
    match *schedule {
        Schedule::Hour { minute } => next_hourly_run(minute, after),
        Schedule::Day { at } => next_daily_run(at, after),
        Schedule::Week { on, at } => next_weekly_run(on, at, after),
    }
}

#[must_use]
pub fn describe_schedule(schedule: &Schedule) -> String {
    match *schedule {
        Schedule::Hour { minute } => format!("Every hour at :{minute:02}"),
        Schedule::Day { at } => format!(
            "Every {} at {}",
            name_part_of_day(at),
            describe_time_of_day(at)
        ),
        Schedule::Week { on, at } => format!(
            "Every {} at {}",
            name_weekday(on),
            describe_time_of_day(at)
        ),
    }
}

fn next_hourly_run(
    minute: u32,
    after: DateTime<Utc>,
) -> Result<DateTime<Utc>, ScheduleProblem> {
    let time = NaiveTime::from_hms_opt(after.hour(), minute, 0)
        .ok_or(ScheduleProblem::InvalidMinute { minute })?;
    let candidate = after.date_naive().and_time(time).and_utc();
    move_past(candidate, after, TimeDelta::hours(1))
}

fn next_daily_run(
    at: TimeOfDay,
    after: DateTime<Utc>,
) -> Result<DateTime<Utc>, ScheduleProblem> {
    let candidate = combine_date_and_time(after.date_naive(), at)?;
    move_past(candidate, after, TimeDelta::days(1))
}

fn next_weekly_run(
    on: Weekday,
    at: TimeOfDay,
    after: DateTime<Utc>,
) -> Result<DateTime<Utc>, ScheduleProblem> {
    let target_day = on.num_days_from_monday();
    let current_day = after.weekday().num_days_from_monday();
    let days_ahead =
        (DAYS_PER_WEEK + target_day - current_day) % DAYS_PER_WEEK;
    let date = after
        .date_naive()
        .checked_add_days(Days::new(u64::from(days_ahead)))
        .ok_or(ScheduleProblem::OutOfRange)?;
    let candidate = combine_date_and_time(date, at)?;
    move_past(candidate, after, TimeDelta::weeks(1))
}

fn combine_date_and_time(
    date: NaiveDate,
    at: TimeOfDay,
) -> Result<DateTime<Utc>, ScheduleProblem> {
    let time = NaiveTime::from_hms_opt(at.hour, at.minute, 0).ok_or(
        ScheduleProblem::InvalidTimeOfDay {
            hour: at.hour,
            minute: at.minute,
        },
    )?;
    Ok(date.and_time(time).and_utc())
}

fn move_past(
    candidate: DateTime<Utc>,
    after: DateTime<Utc>,
    period: TimeDelta,
) -> Result<DateTime<Utc>, ScheduleProblem> {
    if candidate > after {
        return Ok(candidate);
    }
    candidate
        .checked_add_signed(period)
        .ok_or(ScheduleProblem::OutOfRange)
}

fn name_part_of_day(at: TimeOfDay) -> &'static str {
    if at.hour < NIGHT_ENDS_BEFORE_HOUR {
        return "night";
    }
    "day"
}

fn describe_time_of_day(at: TimeOfDay) -> String {
    format!("{:02}:{:02}", at.hour, at.minute)
}

fn name_weekday(weekday: Weekday) -> &'static str {
    match weekday {
        Weekday::Mon => "Monday",
        Weekday::Tue => "Tuesday",
        Weekday::Wed => "Wednesday",
        Weekday::Thu => "Thursday",
        Weekday::Fri => "Friday",
        Weekday::Sat => "Saturday",
        Weekday::Sun => "Sunday",
    }
}
