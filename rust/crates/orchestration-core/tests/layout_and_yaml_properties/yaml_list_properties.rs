use orchestration_core::device::RunnerTarget;
use orchestration_core::workflow::{
    AgentConnection, StepKind, Workflow, WorkflowAgent,
};
use orchestration_core::workflow_document::render_workflow_document;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::routing_fixtures::routing_agent;
use crate::workflow_strategies::workflow_from_parts;
use crate::yaml_reading::{
    decode_yaml_list, find_field, is_default_ignorable,
};
use crate::yaml_scalar_properties::{hostile_text, render_task};

const REQUIRES_FIELD: &str = "    requires: ";
const AFTER_FIELD: &str = "    after: ";
const EMPTY_LIST: &str = "[]";
const LARGEST_LIST_LENGTH: usize = 5;
const VISIBLE_PREFIX: &str = "Visible ";

fn document_with_labels(labels: &[String]) -> String {
    let agent = WorkflowAgent {
        runs_on: RunnerTarget::RunnerWithLabels {
            labels: labels.to_vec(),
        },
        ..routing_agent(0, StepKind::Agent)
    };
    render_workflow_document(&workflow_from_parts(vec![agent], Vec::new()))
}

fn workflow_with_upstream_names(upstream_names: &[String]) -> Workflow {
    let joining_agent = routing_agent(0, StepKind::Agent);
    let mut agents = vec![joining_agent.clone()];
    let mut connections = Vec::new();
    for (number, name) in (1_u128..).zip(upstream_names) {
        let upstream = WorkflowAgent {
            name: name.clone(),
            ..routing_agent(number, StepKind::Agent)
        };
        connections
            .push(AgentConnection::plain(upstream.id, joining_agent.id));
        agents.push(upstream);
    }
    workflow_from_parts(agents, connections)
}

fn read_after_lists(document: &str) -> Vec<Vec<String>> {
    let mut after_lists = Vec::new();
    for line in document.lines() {
        if let Some(rendered) = line.strip_prefix(AFTER_FIELD) {
            after_lists.push(decode_yaml_list(rendered).unwrap_or_default());
        }
    }
    after_lists
}

fn sorted(texts: &[String]) -> Vec<String> {
    let mut sorted_texts = texts.to_vec();
    sorted_texts.sort();
    sorted_texts
}

proptest! {
    #[test]
    fn test_render_yaml_list_property_labels_round_trip(
        labels in vec(hostile_text(), 0..=LARGEST_LIST_LENGTH),
    ) {
        let document = document_with_labels(&labels);

        let rendered = find_field(&document, REQUIRES_FIELD);

        prop_assert_eq!(rendered.and_then(decode_yaml_list), Some(labels));
    }

    #[test]
    fn test_render_yaml_list_property_no_items_render_as_empty_brackets(
        task in hostile_text(),
    ) {
        let agent = WorkflowAgent {
            task,
            runs_on: RunnerTarget::RunnerWithLabels { labels: Vec::new() },
            ..routing_agent(0, StepKind::Agent)
        };
        let workflow = workflow_from_parts(vec![agent], Vec::new());

        let document = render_workflow_document(&workflow);

        let requires = find_field(&document, REQUIRES_FIELD);
        let after = find_field(&document, AFTER_FIELD);
        prop_assert_eq!(requires, Some(EMPTY_LIST));
        prop_assert_eq!(after, Some(EMPTY_LIST));
    }

    #[test]
    fn test_render_yaml_list_property_upstream_names_round_trip(
        upstream_names in vec(hostile_text(), 1..=LARGEST_LIST_LENGTH),
    ) {
        let workflow = workflow_with_upstream_names(&upstream_names);

        let document = render_workflow_document(&workflow);

        let after_lists = read_after_lists(&document);
        let joining_list = after_lists.iter().find(|list| !list.is_empty());
        prop_assert_eq!(
            joining_list.map(|list| sorted(list)),
            Some(sorted(&upstream_names))
        );
    }

    #[test]
    fn test_is_hidden_character_property_controls_never_appear_raw(
        task in hostile_text(),
    ) {
        let rendered = render_task(&task);

        prop_assert!(
            !rendered.chars().any(char::is_control),
            "{:?}",
            rendered
        );
    }

    #[test]
    fn test_is_hidden_character_property_invisibles_never_appear_raw(
        task in hostile_text(),
    ) {
        let rendered = render_task(&task);

        let raw_invisible = rendered.chars().find(|character| {
            is_default_ignorable(*character)
        });
        prop_assert_eq!(raw_invisible, None, "{:?}", rendered);
    }

    #[test]
    fn test_is_hidden_character_property_visible_text_stays_readable(
        visible in "[a-zA-Z0-9àéüßжд中文😀🚀 .,!?]{0,20}",
    ) {
        let task = format!("{VISIBLE_PREFIX}{visible}");

        let rendered = render_task(&task);

        prop_assert_eq!(rendered, format!("\"{task}\""));
    }
}
