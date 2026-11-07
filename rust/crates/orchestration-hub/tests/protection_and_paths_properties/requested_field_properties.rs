use proptest::prelude::*;
use serde_json::{Value, json};

use crate::requested_action_support::{
    TASK_FOLDER_NAME, any_file_tool, any_task_folder, any_text_tool, describe,
};

fn any_known_tool() -> impl Strategy<Value = (&'static str, &'static str)> {
    let file_tool = any_file_tool().prop_map(|(name, field, _)| (name, field));
    let text_tool = any_text_tool().prop_map(|(name, field, _)| (name, field));
    prop_oneof![file_tool, text_tool, Just(("Bash", "command"))]
}

fn any_non_text_value() -> impl Strategy<Value = Value> {
    prop_oneof![
        Just(json!(42)),
        Just(json!(false)),
        Just(json!(null)),
        Just(json!(["a", "b"])),
        Just(json!({ "inner": "a" })),
    ]
}

proptest! {
    #[test]
    fn test_describe_requested_action_property_keeps_the_tool_name(
        task_folder in any_task_folder(),
        tool_name in "\\PC{0,20}",
        input in proptest::collection::btree_map(
            "[a-z_]{1,10}",
            "\\PC{0,10}",
            0..4,
        ),
    ) {
        let described = describe(&tool_name, json!(input), &task_folder)?;

        prop_assert_eq!(described.tool, tool_name);
    }

    #[test]
    fn test_find_telling_detail_property_missing_field_shows_the_input(
        task_folder in any_task_folder(),
        (tool_name, field) in any_known_tool(),
        other in "[a-z]{1,8}",
        value in "[a-z ]{0,12}",
    ) {
        prop_assume!(other != field && other != "description");
        let input = json!({ other.clone(): value });

        let described = describe(tool_name, input.clone(), &task_folder)?;

        prop_assert_eq!(described.command, input.to_string());
        prop_assert_eq!(described.summary, format!("Use {tool_name}"));
    }

    #[test]
    fn test_find_telling_detail_property_non_text_field_shows_the_input(
        task_folder in any_task_folder(),
        (tool_name, field) in any_known_tool(),
        value in any_non_text_value(),
    ) {
        let input = json!({ field: value });

        let described = describe(tool_name, input.clone(), &task_folder)?;

        prop_assert_eq!(described.command, input.to_string());
    }

    #[test]
    fn test_find_telling_detail_property_tool_names_match_exactly(
        task_folder in any_task_folder(),
        (tool_name, field) in any_known_tool(),
        detail in "[a-z]{1,12}",
        is_lower in any::<bool>(),
    ) {
        let respelled = if is_lower {
            tool_name.to_lowercase()
        } else {
            format!("{tool_name} ")
        };
        let input = json!({ field: detail });

        let described = describe(&respelled, input.clone(), &task_folder)?;

        prop_assert_eq!(described.command, input.to_string());
        let expected_summary = format!("Use {}", respelled.trim());
        prop_assert_eq!(described.summary, expected_summary);
    }

    #[test]
    fn test_read_text_field_property_inputs_that_are_not_objects(
        task_folder in any_task_folder(),
        (tool_name, _) in any_known_tool(),
        input in prop_oneof![
            Just(json!("file_path")), Just(json!(["command"])),
            Just(json!(null)), Just(json!(3)),
        ],
    ) {
        let described = describe(tool_name, input.clone(), &task_folder)?;

        prop_assert_eq!(described.command, input.to_string());
        prop_assert_eq!(described.summary, format!("Use {tool_name}"));
    }

    #[test]
    fn test_read_text_field_property_nested_fields_are_not_read(
        task_folder in any_task_folder(),
        (tool_name, field) in any_known_tool(),
        detail in "[a-z]{1,12}",
    ) {
        let input = json!({ "options": { field: detail } });

        let described = describe(tool_name, input.clone(), &task_folder)?;

        prop_assert_eq!(described.command, input.to_string());
    }

    #[test]
    fn test_read_text_field_property_empty_text_is_still_the_detail(
        task_folder in any_task_folder(),
        (tool_name, field) in any_known_tool(),
    ) {
        let input = json!({ field: "" });

        let described = describe(tool_name, input, &task_folder)?;

        prop_assert_eq!(described.command, "");
        prop_assert!(!described.summary.is_empty());
        prop_assert_eq!(described.summary.trim(), described.summary.as_str());
    }

    #[test]
    fn test_continues_a_name_property_letters_and_digits_continue(
        task_folder in any_task_folder(),
        ending in "[a-zA-Z0-9éüñ中]{1,4}",
    ) {
        let sibling = format!("{task_folder}{ending}");
        let input = json!({ "command": format!("ls {sibling}") });

        let described = describe("Bash", input, &task_folder)?;

        prop_assert_eq!(described.command, format!("ls {sibling}"));
    }

    #[test]
    fn test_continues_a_name_property_name_punctuation_continues(
        task_folder in any_task_folder(),
        punctuation in prop::sample::select(
            vec!['-', '_', '.', '~', '+', '@'],
        ),
        rest in "[a-z]{0,4}",
    ) {
        let sibling = format!("{task_folder}{punctuation}{rest}");
        let input = json!({ "command": format!("ls {sibling}") });

        let described = describe("Bash", input, &task_folder)?;

        prop_assert_eq!(described.command, format!("ls {sibling}"));
    }

    #[test]
    fn test_continues_a_name_property_separators_end_the_name(
        task_folder in any_task_folder(),
        separator in prop::sample::select(vec![
            '/', ' ', '"', '\'', ';', '|', '&', ')', '>', '<', '\n', ':',
        ]),
        rest in "[a-z]{0,4}",
    ) {
        let input = json!({
            "command": format!("ls {task_folder}{separator}{rest}"),
        });

        let described = describe("Bash", input, &task_folder)?;

        let expected = format!("ls {TASK_FOLDER_NAME}{separator}{rest}");
        prop_assert_eq!(described.command, expected);
    }
}
