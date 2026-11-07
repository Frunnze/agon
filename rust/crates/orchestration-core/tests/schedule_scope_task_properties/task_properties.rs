use orchestration_core::agent_place::AgentPlace;
use orchestration_core::task::{Task, TaskStatus};
use orchestration_core::task_summary::{
    TaskSummary, describe_task_summary, summarize_tasks,
};
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::Value;

use crate::entity_strategies::{
    agent_place, example_task, one_agent_doer, task_status, task_with_doer,
};

const MOST_TASKS: usize = 12;
const MOST_COUNT: usize = 30;
const AGENT_PLACE_FIELD: &str = "agent_place";
const PART_SEPARATOR: &str = " · ";
const DONE_WORD: &str = "done";
const ALL_STATUSES: [TaskStatus; 5] = [
    TaskStatus::ToDo,
    TaskStatus::Running,
    TaskStatus::WaitingForApproval,
    TaskStatus::Failed,
    TaskStatus::Done,
];

fn tasks() -> impl Strategy<Value = Vec<Task>> {
    vec(task_with_doer(one_agent_doer()), 0..MOST_TASKS)
}

fn count_of(summary: &TaskSummary, status: TaskStatus) -> usize {
    match status {
        TaskStatus::ToDo => summary.to_do,
        TaskStatus::Running => summary.running,
        TaskStatus::WaitingForApproval => summary.waiting_for_approval,
        TaskStatus::Failed => summary.failed,
        TaskStatus::Done => summary.done,
    }
}

fn read_back(encoded: Value) -> Result<Task, TestCaseError> {
    serde_json::from_value(encoded)
        .map_err(|error| TestCaseError::fail(error.to_string()))
}

fn encode(task: &Task) -> Result<Value, TestCaseError> {
    serde_json::to_value(task)
        .map_err(|error| TestCaseError::fail(error.to_string()))
}

fn small_summary() -> impl Strategy<Value = TaskSummary> {
    (
        0..MOST_COUNT,
        0..MOST_COUNT,
        0..MOST_COUNT,
        0..MOST_COUNT,
        0..MOST_COUNT,
    )
        .prop_map(
            |(to_do, running, waiting_for_approval, failed, done)| {
                TaskSummary {
                    to_do,
                    running,
                    waiting_for_approval,
                    failed,
                    done,
                }
            },
        )
}

proptest! {
    #[test]
    fn test_place_of_tasks_saved_before_places_property_runs_on_the_computer(
        task in task_with_doer(one_agent_doer()),
        stored_place in proptest::option::of(agent_place()),
    ) {
        let mut encoded = encode(&Task { agent_place: stored_place, ..task })?;
        let removed = encoded
            .as_object_mut()
            .and_then(|fields| fields.remove(AGENT_PLACE_FIELD));
        prop_assert!(removed.is_some());

        let decoded = read_back(encoded)?;

        prop_assert_eq!(decoded.agent_place, Some(AgentPlace::LocalProcess));
    }

    #[test]
    fn test_place_of_tasks_saved_before_places_property_keeps_a_stored_place(
        place in agent_place(),
    ) {
        let task = Task {
            agent_place: Some(place),
            ..example_task()
        };

        let decoded = read_back(encode(&task)?)?;

        prop_assert_eq!(decoded, task);
    }

    #[test]
    fn test_place_of_tasks_saved_before_places_property_keeps_a_cleared_place(
        task in task_with_doer(one_agent_doer()),
    ) {
        let cleared = Task { agent_place: None, ..task };

        let encoded = encode(&cleared)?;
        let decoded = read_back(encoded.clone())?;

        prop_assert_eq!(&encoded[AGENT_PLACE_FIELD], &Value::Null);
        prop_assert_eq!(decoded.agent_place, None);
    }

    #[test]
    fn test_summarize_tasks_property_one_more_task_adds_one_to_its_status(
        listed in tasks(),
        extra in task_with_doer(one_agent_doer()),
    ) {
        let before = summarize_tasks(&listed);
        let mut grown = listed.clone();
        grown.push(extra.clone());

        let after = summarize_tasks(&grown);

        for status in ALL_STATUSES {
            let added = usize::from(status == extra.status);
            prop_assert_eq!(
                count_of(&after, status),
                count_of(&before, status) + added
            );
        }
    }

    #[test]
    fn test_count_tasks_with_status_property_counts_sum_to_the_task_count(
        listed in tasks(),
    ) {
        let summary = summarize_tasks(&listed);

        let mut total = 0;
        for status in ALL_STATUSES {
            total += count_of(&summary, status);
        }
        prop_assert_eq!(total, listed.len());
    }

    #[test]
    fn test_count_tasks_with_status_property_one_status_fills_one_count(
        listed in tasks(),
        status in task_status(),
    ) {
        let same_status: Vec<Task> = listed
            .into_iter()
            .map(|task| Task { status, ..task })
            .collect();

        let summary = summarize_tasks(&same_status);

        for other in ALL_STATUSES {
            let expected = if other == status { same_status.len() } else { 0 };
            prop_assert_eq!(count_of(&summary, other), expected);
        }
    }

    #[test]
    fn test_count_tasks_with_status_property_matches_a_counted_list(
        listed in tasks(),
    ) {
        let summary = summarize_tasks(&listed);

        for status in ALL_STATUSES {
            let mut counted = 0;
            for task in &listed {
                if task.status == status {
                    counted += 1;
                }
            }
            prop_assert_eq!(count_of(&summary, status), counted);
        }
    }

    #[test]
    fn test_describe_task_summary_property_done_shows_only_when_all_done(
        summary in small_summary(),
    ) {
        let description = describe_task_summary(&summary);

        let open_count = summary.to_do
            + summary.running
            + summary.waiting_for_approval
            + summary.failed;
        let mentions_done = description.to_lowercase().contains(DONE_WORD);
        prop_assert_eq!(mentions_done, open_count == 0 && summary.done > 0);
    }

    #[test]
    fn test_describe_task_summary_property_each_part_names_a_present_count(
        summary in small_summary(),
    ) {
        let description = describe_task_summary(&summary);

        let open_counts = [
            summary.running,
            summary.waiting_for_approval,
            summary.failed,
            summary.to_do,
        ];
        let present_counts: Vec<usize> = open_counts
            .into_iter()
            .filter(|count| *count > 0)
            .collect();
        if present_counts.is_empty() {
            return Ok(());
        }
        let parts: Vec<&str> = description.split(PART_SEPARATOR).collect();
        prop_assert_eq!(parts.len(), present_counts.len());
        for (part, count) in parts.iter().zip(&present_counts) {
            let number = part.split(' ').next().unwrap_or_default();
            prop_assert_eq!(number, count.to_string());
        }
    }
}
