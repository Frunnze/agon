use chrono::DateTime;
use orchestration_core::agent_kind_label::describe_agent_kind;
use orchestration_core::run_lifecycle::create_run;
use orchestration_core::task::{Task, TaskDoer};
use orchestration_core::workflow::{AgentKind, WorkflowAgent};
use orchestration_core::workflow_document::render_workflow_document;
use proptest::prelude::*;

use crate::entity_strategies::{agent_kind, example_task};
use crate::routing_fixtures::routing_workflow;
use crate::run_fixtures::{RUN_NUMBER, run_identifier, starter};
use crate::workflow_strategies::workflow_from_parts;

const AGENT_LINE_PREFIX: &str = "    agent: ";
const LABEL_SEPARATOR: char = '-';
const DESCRIPTION_SEPARATOR: &str = " ";

fn label_through_a_run(kind: AgentKind) -> Result<String, TestCaseError> {
    let task = Task {
        doer: TaskDoer::OneAgent { agent: kind },
        ..example_task()
    };
    let run = create_run(
        &task,
        None,
        RUN_NUMBER,
        run_identifier(),
        starter(),
        DateTime::UNIX_EPOCH,
    )
    .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
    let only_step = run
        .steps
        .first()
        .ok_or_else(|| TestCaseError::fail("the run has no step"))?;
    Ok(only_step.name.clone())
}

fn label_through_a_document(kind: AgentKind) -> Option<String> {
    let workflow = routing_workflow(1, Vec::new());
    let agents: Vec<WorkflowAgent> = workflow
        .agents
        .into_iter()
        .map(|agent| WorkflowAgent {
            kind: Some(kind),
            ..agent
        })
        .collect();
    let document =
        render_workflow_document(&workflow_from_parts(agents, Vec::new()));
    document
        .lines()
        .find_map(|line| line.strip_prefix(AGENT_LINE_PREFIX))
        .map(str::to_owned)
}

proptest! {
    #[test]
    fn test_label_agent_kind_property_gives_each_kind_its_own_label(
        first in agent_kind(),
        second in agent_kind(),
    ) {
        let first_label = label_through_a_run(first)?;
        let second_label = label_through_a_run(second)?;

        prop_assert_eq!(first_label == second_label, first == second);
    }

    #[test]
    fn test_label_agent_kind_property_is_lowercase_words_joined_by_dashes(
        kind in agent_kind(),
    ) {
        let label = label_through_a_run(kind)?;

        prop_assert!(!label.is_empty());
        for word in label.split(LABEL_SEPARATOR) {
            prop_assert!(!word.is_empty());
            let is_lowercase =
                word.chars().all(|letter| letter.is_ascii_lowercase());
            prop_assert!(is_lowercase);
        }
    }

    #[test]
    fn test_label_agent_kind_property_runs_and_documents_agree(
        kind in agent_kind(),
    ) {
        let run_label = label_through_a_run(kind)?;
        let document_label = label_through_a_document(kind);

        prop_assert_eq!(document_label, Some(run_label));
    }

    #[test]
    fn test_describe_agent_kind_property_lowercases_into_the_label(
        kind in agent_kind(),
    ) {
        let description = describe_agent_kind(kind);
        let label = label_through_a_run(kind)?;

        let dashed_description = description
            .to_lowercase()
            .replace(DESCRIPTION_SEPARATOR, &LABEL_SEPARATOR.to_string());

        prop_assert_eq!(dashed_description, label);
    }

    #[test]
    fn test_describe_agent_kind_property_starts_every_word_capitalized(
        kind in agent_kind(),
    ) {
        let description = describe_agent_kind(kind);

        for word in description.split(DESCRIPTION_SEPARATOR) {
            let first_letter = word.chars().next();
            prop_assert!(
                first_letter.is_some_and(|letter| letter.is_ascii_uppercase())
            );
        }
    }
}
