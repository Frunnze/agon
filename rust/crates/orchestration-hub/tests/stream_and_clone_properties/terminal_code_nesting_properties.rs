use orchestration_core::workflow::AgentKind;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::Index;
use serde_json::json;

use crate::claude_lines::parse_claude;
use crate::claude_tool_results::{
    ToolOutcome, ToolResultContent, tool_result_line,
};
use crate::codex_lines::{completed_line, file_change_item};
use crate::stream_support::read_container_events;
use crate::text_shapes::{any_code_placements, any_colour_code, insert_codes};

const LARGEST_TEXT_COUNT: usize = 4;

type Placements = Vec<(Index, String)>;

fn colour_each(texts: &[String], placements: &Placements) -> Vec<String> {
    let mut coloured_texts = Vec::new();
    for text in texts {
        coloured_texts.push(insert_codes(text, placements));
    }
    coloured_texts
}

fn tool_failure_lines(texts: &[String]) -> Vec<String> {
    let content = ToolResultContent::TextBlocks(texts.to_vec());
    vec![tool_result_line(&content, ToolOutcome::Failed)]
}

fn file_change_lines(paths: &[String]) -> Vec<String> {
    let mut changes = Vec::new();
    for path in paths {
        changes.push((format!("/workspace/{path}"), "update".to_owned()));
    }
    vec![completed_line(&file_change_item(&changes, "completed"))]
}

fn result_line(is_error: bool, duration: u32, result: &str) -> String {
    json!({
        "type": "result",
        "subtype": "success",
        "is_error": is_error,
        "duration_ms": duration,
        "total_cost_usd": f64::from(duration) / 7.0,
        "result": result,
    })
    .to_string()
}

proptest! {
    #[test]
    fn test_strip_terminal_codes_in_texts_property_nested_texts_read_as_bare(
        texts in vec(any::<String>(), 1..LARGEST_TEXT_COUNT),
        paths in vec("[a-z0-9_]{1,8}\\.rs", 1..LARGEST_TEXT_COUNT),
        placements in any_code_placements(any_colour_code()),
    ) {
        let coloured_texts = colour_each(&texts, &placements);
        let coloured_paths = colour_each(&paths, &placements);

        let claude = AgentKind::ClaudeCode;
        let bare_failures =
            read_container_events(claude, &tool_failure_lines(&texts));
        let coloured_failure_lines = tool_failure_lines(&coloured_texts);
        let coloured_failures =
            read_container_events(claude, &coloured_failure_lines);
        let codex = AgentKind::Codex;
        let bare_changes =
            read_container_events(codex, &file_change_lines(&paths));
        let coloured_changes =
            read_container_events(codex, &file_change_lines(&coloured_paths));

        prop_assert_eq!(coloured_failures, bare_failures);
        prop_assert_eq!(coloured_changes, bare_changes);
    }

    #[test]
    fn test_strip_terminal_codes_in_texts_property_flags_and_numbers_kept(
        is_error in any::<bool>(),
        duration in any::<u32>(),
        result in any::<String>(),
        placements in any_code_placements(any_colour_code()),
    ) {
        let coloured_result = insert_codes(&result, &placements);

        let bare_line = result_line(is_error, duration, &result);
        let bare_events = parse_claude(&bare_line);
        let coloured_line = result_line(is_error, duration, &coloured_result);
        let coloured_events = parse_claude(&coloured_line);

        prop_assert_eq!(coloured_events, bare_events);
    }

    #[test]
    fn test_strip_terminal_codes_in_texts_property_field_names_stay_as_given(
        text in any::<String>(),
        code in any_colour_code(),
    ) {
        let message = json!({"content": [{"type": "text", "text": text}]});
        let mut coloured_message = json!({"type": "assistant"});
        coloured_message[format!("{code}message")] = message.clone();
        let mut coloured_type = json!({"message": message});
        coloured_type[format!("{code}type")] = json!("assistant");

        let message_events = parse_claude(&coloured_message.to_string());
        let type_events = parse_claude(&coloured_type.to_string());

        prop_assert_eq!(message_events, Vec::new());
        prop_assert_eq!(type_events, Vec::new());
    }
}
