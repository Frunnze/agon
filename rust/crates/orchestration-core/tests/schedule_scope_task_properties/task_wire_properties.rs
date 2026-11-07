use chrono::Weekday;
use orchestration_core::task::{Schedule, TaskDoer, TaskStatus};
use orchestration_core::task_summary::TaskSummary;
use proptest::prelude::*;
use serde::Serialize;
use serde::de::DeserializeOwned;
use serde_json::{Value, json};

use crate::entity_strategies::{agent_kind, task_status, valid_schedule};
use crate::workflow_strategies::workflow_identifier;

fn to_json<Written: Serialize>(
    written: &Written,
) -> Result<Value, TestCaseError> {
    serde_json::to_value(written)
        .map_err(|error| TestCaseError::fail(error.to_string()))
}

fn from_json<Read: DeserializeOwned>(
    encoded: Value,
) -> Result<Read, TestCaseError> {
    serde_json::from_value(encoded)
        .map_err(|error| TestCaseError::fail(error.to_string()))
}

fn expected_schedule_json(schedule: Schedule) -> Value {
    match schedule {
        Schedule::Hour { minute } => {
            json!({"every": "hour", "minute": minute})
        }
        Schedule::Day { at } => json!({
            "every": "day",
            "at": {"hour": at.hour, "minute": at.minute},
        }),
        Schedule::Week { on, at } => json!({
            "every": "week",
            "on": weekday_wire_name(on),
            "at": {"hour": at.hour, "minute": at.minute},
        }),
    }
}

fn weekday_wire_name(on: Weekday) -> &'static str {
    match on {
        Weekday::Mon => "Mon",
        Weekday::Tue => "Tue",
        Weekday::Wed => "Wed",
        Weekday::Thu => "Thu",
        Weekday::Fri => "Fri",
        Weekday::Sat => "Sat",
        Weekday::Sun => "Sun",
    }
}

fn expected_status_name(status: TaskStatus) -> &'static str {
    match status {
        TaskStatus::ToDo => "to_do",
        TaskStatus::Running => "running",
        TaskStatus::WaitingForApproval => "waiting_for_approval",
        TaskStatus::Failed => "failed",
        TaskStatus::Done => "done",
    }
}

proptest! {
    #[test]
    fn test_schedule_property_writes_the_shape_the_app_reads(
        schedule in valid_schedule(),
    ) {
        let encoded = to_json(&schedule)?;

        prop_assert_eq!(&encoded, &expected_schedule_json(schedule));
        prop_assert_eq!(from_json::<Schedule>(encoded)?, schedule);
    }

    #[test]
    fn test_task_status_property_writes_the_app_status_names(
        status in task_status(),
    ) {
        let encoded = to_json(&status)?;

        prop_assert_eq!(&encoded, &json!(expected_status_name(status)));
        prop_assert_eq!(from_json::<TaskStatus>(encoded)?, status);
    }

    #[test]
    fn test_task_doer_property_writes_the_app_doer_kinds(
        agent in agent_kind(),
        uses_workflow in any::<bool>(),
    ) {
        let doer = if uses_workflow {
            TaskDoer::Workflow {
                workflow_id: workflow_identifier(),
            }
        } else {
            TaskDoer::OneAgent { agent }
        };

        let encoded = to_json(&doer)?;

        let expected_kind =
            if uses_workflow { "workflow" } else { "one_agent" };
        prop_assert_eq!(&encoded["kind"], &json!(expected_kind));
        prop_assert_eq!(from_json::<TaskDoer>(encoded)?, doer);
    }

    #[test]
    fn test_task_summary_property_survives_json_with_every_count(
        counts in any::<[u16; 5]>(),
    ) {
        let summary = TaskSummary {
            to_do: usize::from(counts[0]),
            running: usize::from(counts[1]),
            waiting_for_approval: usize::from(counts[2]),
            failed: usize::from(counts[3]),
            done: usize::from(counts[4]),
        };

        let encoded = to_json(&summary)?;

        let expected = json!({
            "to_do": counts[0],
            "running": counts[1],
            "waiting_for_approval": counts[2],
            "failed": counts[3],
            "done": counts[4],
        });
        prop_assert_eq!(&encoded, &expected);
        prop_assert_eq!(from_json::<TaskSummary>(encoded)?, summary);
    }
}
