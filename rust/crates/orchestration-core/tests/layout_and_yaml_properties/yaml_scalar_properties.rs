use orchestration_core::device::RunnerTarget;
use orchestration_core::workflow::{StepKind, Workflow, WorkflowAgent};
use orchestration_core::workflow_document::render_workflow_document;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::routing_fixtures::routing_agent;
use crate::workflow_strategies::workflow_from_parts;
use crate::yaml_reading::{
    decode_yaml_scalar, find_field, is_line_break, is_yaml_printable,
};

pub const WORKFLOW_NAME_FIELD: &str = "name: ";
pub const TASK_FIELD: &str = "    task: ";
const PLAIN_TEXT: &str = "plain";
const LONGEST_HOSTILE_TEXT: usize = 24;
const RESERVED_WORDS: [&str; 9] =
    ["true", "false", "null", "yes", "no", "on", "off", "y", "n"];
const HIDDEN_SAMPLES: [char; 12] = [
    '"', '\\', '\n', '\t', '\r', '\u{85}', '\u{2028}', '\u{2029}', '\u{61C}',
    '\u{FEFF}', '\u{FFFE}', '\u{FFFF}',
];

pub fn hostile_character() -> impl Strategy<Value = char> {
    prop_oneof![
        any::<char>(),
        proptest::char::range('\u{0}', '\u{9F}'),
        proptest::sample::select(HIDDEN_SAMPLES.to_vec()),
        proptest::char::range('\u{2000}', '\u{206F}'),
        proptest::char::range('\u{E0000}', '\u{E007F}'),
        proptest::char::range('\u{FE00}', '\u{FE0F}'),
    ]
}

pub fn hostile_text() -> impl Strategy<Value = String> {
    vec(hostile_character(), 0..=LONGEST_HOSTILE_TEXT)
        .prop_map(|characters| characters.into_iter().collect())
}

pub fn document_with(workflow_name: &str, task: &str) -> String {
    let agent = WorkflowAgent {
        task: task.to_owned(),
        runs_on: RunnerTarget::AnyFreeRunner,
        ..routing_agent(0, StepKind::Agent)
    };
    let workflow = Workflow {
        name: workflow_name.to_owned(),
        ..workflow_from_parts(vec![agent], Vec::new())
    };
    render_workflow_document(&workflow)
}

pub fn render_task(task: &str) -> String {
    let document = document_with(PLAIN_TEXT, task);
    find_field(&document, TASK_FIELD)
        .unwrap_or_default()
        .to_owned()
}

fn reserved_word_in_any_case() -> impl Strategy<Value = String> {
    let word = proptest::sample::select(RESERVED_WORDS.to_vec());
    (word, vec(any::<bool>(), RESERVED_WORDS.len())).prop_map(
        |(word, uppercase_mask)| {
            let mut cased = String::new();
            for (character, is_upper) in word.chars().zip(uppercase_mask) {
                let shown = if is_upper {
                    character.to_ascii_uppercase()
                } else {
                    character
                };
                cased.push(shown);
            }
            cased
        },
    )
}

fn text_outside_the_plain_alphabet() -> impl Strategy<Value = String> {
    prop_oneof![
        "[0-9-][a-z0-9-]{0,10}",
        "[a-z]{0,5}[^a-z0-9-][a-z0-9-]{0,5}",
        Just(String::new()),
    ]
}

proptest! {
    #[test]
    fn test_render_yaml_scalar_property_any_text_round_trips(
        workflow_name in hostile_text(),
        task in hostile_text(),
    ) {
        let document = document_with(&workflow_name, &task);

        let name_field = find_field(&document, WORKFLOW_NAME_FIELD);
        let task_field = find_field(&document, TASK_FIELD);

        let decoded_name = name_field.and_then(decode_yaml_scalar);
        let decoded_task = task_field.and_then(decode_yaml_scalar);
        prop_assert_eq!(decoded_name, Some(workflow_name));
        prop_assert_eq!(decoded_task, Some(task));
    }

    #[test]
    fn test_render_yaml_scalar_property_text_never_adds_lines(
        workflow_name in hostile_text(),
        task in hostile_text(),
    ) {
        let document = document_with(&workflow_name, &task);
        let plain_document = document_with(PLAIN_TEXT, PLAIN_TEXT);

        let line_count = document.split(is_line_break).count();
        let plain_line_count = plain_document.split(is_line_break).count();
        prop_assert_eq!(line_count, plain_line_count);
    }

    #[test]
    fn test_render_yaml_scalar_property_distinct_texts_stay_distinct(
        first in hostile_text(),
        second in hostile_text(),
    ) {
        prop_assume!(first != second);

        prop_assert_ne!(render_task(&first), render_task(&second));
    }

    #[test]
    fn test_is_plain_scalar_property_plain_words_render_bare(
        word in "[a-z][a-z0-9-]{0,20}",
    ) {
        prop_assume!(!RESERVED_WORDS.contains(&word.as_str()));

        prop_assert_eq!(render_task(&word), word);
    }

    #[test]
    fn test_is_plain_scalar_property_reserved_words_are_quoted(
        word in reserved_word_in_any_case(),
    ) {
        let rendered = render_task(&word);

        prop_assert_eq!(rendered, format!("\"{word}\""));
    }

    #[test]
    fn test_is_plain_scalar_property_other_texts_are_quoted(
        text in text_outside_the_plain_alphabet(),
    ) {
        let rendered = render_task(&text);

        prop_assert!(rendered.starts_with('"'), "{}", rendered);
        prop_assert!(rendered.ends_with('"'), "{}", rendered);
        prop_assert_eq!(decode_yaml_scalar(&rendered), Some(text));
    }

    #[test]
    fn test_quote_yaml_text_property_output_is_printable_yaml(
        task in hostile_text(),
    ) {
        let rendered = render_task(&task);

        for character in rendered.chars() {
            prop_assert!(is_yaml_printable(character), "{:?}", character);
            prop_assert!(!is_line_break(character), "{:?}", character);
        }
    }

    #[test]
    fn test_quote_yaml_text_property_quotes_and_backslashes_round_trip(
        task in "[a u0-9]{0,9}[\"\\\\][\"\\\\a u0-9]{0,9}",
    ) {
        let rendered = render_task(&task);

        let body = rendered.strip_prefix('"').and_then(|rest| {
            rest.strip_suffix('"')
        });
        prop_assert!(body.is_some(), "{}", rendered);
        prop_assert_eq!(decode_yaml_scalar(&rendered), Some(task));
    }

    #[test]
    fn test_quote_yaml_text_property_characters_past_the_bmp_round_trip(
        prefix in "[a-z]{0,3}",
        far_character in proptest::char::range('\u{10000}', '\u{10FFFF}'),
        suffix in "[0-9a-f]{0,3}",
    ) {
        let task = format!("{prefix}{far_character}{suffix}");

        let rendered = render_task(&task);

        prop_assert_eq!(decode_yaml_scalar(&rendered), Some(task));
    }
}
