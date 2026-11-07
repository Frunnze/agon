use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_event::AgentEvent;
use proptest::collection::{btree_map, vec};
use proptest::prelude::*;
use serde_json::{Map, Value, json};

use crate::agent_reading::parse_agent_line;
use crate::json_texts::reads_as_json;

const JSON_READING_AGENTS: [AgentKind; 2] =
    [AgentKind::ClaudeCode, AgentKind::Codex];
const LARGEST_FIELD_COUNT: usize = 4;
const LARGEST_DEPTH: u32 = 3;

fn any_json_leaf() -> impl Strategy<Value = Value> {
    prop_oneof![
        Just(Value::Null),
        any::<bool>().prop_map(Value::Bool),
        any::<i64>().prop_map(|number| json!(number)),
        any::<String>().prop_map(Value::String),
    ]
}

fn any_json_value() -> impl Strategy<Value = Value> {
    any_json_leaf().prop_recursive(LARGEST_DEPTH, 16, 4, |inner| {
        prop_oneof![
            vec(inner.clone(), 0..LARGEST_FIELD_COUNT).prop_map(Value::Array),
            btree_map("[a-z_]{1,8}", inner, 0..LARGEST_FIELD_COUNT).prop_map(
                |fields| Value::Object(fields.into_iter().collect())
            ),
        ]
    })
}

fn any_untyped_container() -> impl Strategy<Value = Value> {
    let fields = btree_map("k_[a-z]{1,6}", any_json_value(), 0..4);
    prop_oneof![
        fields.prop_map(|fields| {
            let object: Map<String, Value> = fields.into_iter().collect();
            Value::Object(object)
        }),
        vec(any_json_value(), 0..4).prop_map(Value::Array),
    ]
}

fn any_plain_text() -> impl Strategy<Value = String> {
    concat!(
        "[a-zA-Z0-9é中😀(<!#]",
        "[a-zA-Z0-9é中😀 .,:;!?(){}<>\\[\\]\"'#=-]{0,60}",
    )
    .prop_filter("text that is not json", |text| {
        !reads_as_json(text) && !text.trim_end().is_empty()
    })
}

fn read_with_each_agent(line: &str) -> Vec<Vec<AgentEvent>> {
    let mut events_of_each_agent = Vec::new();
    for agent in JSON_READING_AGENTS {
        events_of_each_agent.push(parse_agent_line(agent, line));
    }
    events_of_each_agent
}

proptest! {
    #[test]
    fn test_reads_as_json_property_objects_and_arrays_are_never_speech(
        container in any_untyped_container(),
    ) {
        let line = container.to_string();

        for agent_events in read_with_each_agent(&line) {
            prop_assert_eq!(agent_events, Vec::new());
        }
    }

    #[test]
    fn test_reads_as_json_property_padded_containers_stay_json(
        container in any_untyped_container(),
        padding in "[ \t]{1,4}",
    ) {
        let line = format!("{padding}{container}{padding}");

        for agent_events in read_with_each_agent(&line) {
            prop_assert_eq!(agent_events, Vec::new());
        }
    }

    #[test]
    fn test_reads_as_json_property_scalars_are_read_as_text(
        scalar in any_json_leaf(),
    ) {
        let line = scalar.to_string();
        prop_assume!(!line.trim().is_empty());

        let expected = vec![AgentEvent::Said(line.trim_end().to_owned())];
        for agent_events in read_with_each_agent(&line) {
            prop_assert_eq!(&agent_events, &expected);
        }
    }

    #[test]
    fn test_describe_unread_line_property_plain_text_becomes_one_speech(
        text in any_plain_text(),
    ) {
        let expected = vec![AgentEvent::Said(text.trim_end().to_owned())];

        for agent_events in read_with_each_agent(&text) {
            prop_assert_eq!(&agent_events, &expected);
        }
    }

    #[test]
    fn test_describe_unread_line_property_agents_agree_on_unread_lines(
        line in any::<String>(),
    ) {
        prop_assume!(!reads_as_json(&line));

        let events_of_each_agent = read_with_each_agent(&line);

        prop_assert_eq!(&events_of_each_agent[0], &events_of_each_agent[1]);
    }

    #[test]
    fn test_describe_unread_line_property_gives_at_most_one_speech(
        line in any::<String>(),
        trailing_spaces in "[ \t\r]{0,3}",
    ) {
        prop_assume!(!reads_as_json(&line));
        let padded_line = format!("{line}{trailing_spaces}");

        for agent_events in read_with_each_agent(&padded_line) {
            prop_assert!(agent_events.len() <= 1);
            for agent_event in &agent_events {
                let AgentEvent::Said(text) = agent_event else {
                    let unexpected = format!("{agent_event:?}");
                    return Err(TestCaseError::fail(unexpected));
                };
                prop_assert!(!text.trim().is_empty());
                prop_assert_eq!(text.trim_end(), text.as_str());
            }
        }
    }
}
