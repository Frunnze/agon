use orchestration_hub::command_label::label_shell_command;
use proptest::prelude::*;
use serde_json::json;

use crate::requested_action_support::{
    SHORTENED_MARKER, TASK_FOLDER_NAME, any_file_tool, any_task_folder,
    any_text_tool, describe, is_one_short_line,
};

fn any_line_break() -> impl Strategy<Value = &'static str> {
    prop_oneof![
        Just("\n"),
        Just("\r\n"),
        Just("\r"),
        Just("\u{2028}"),
        Just("\u{2029}"),
        Just("\u{85}"),
        Just("\u{0B}"),
        Just("\u{0C}"),
    ]
}

proptest! {
    #[test]
    fn test_read_agent_description_property_blank_ones_are_ignored(
        task_folder in any_task_folder(),
        (tool_name, field, _) in any_file_tool(),
        name in "[a-z]{1,8}\\.rs",
        blank in "[ \t\n]{0,6}",
    ) {
        let detail = format!("{task_folder}/{name}");
        let with_blank = json!({ field: detail, "description": blank });
        let without = json!({ field: detail });

        let described = describe(tool_name, with_blank, &task_folder)?;
        let plain = describe(tool_name, without, &task_folder)?;

        prop_assert_eq!(described, plain);
    }

    #[test]
    fn test_read_agent_description_property_only_text_descriptions_count(
        task_folder in any_task_folder(),
        (tool_name, field, _) in any_text_tool(),
        detail in "[a-z ]{1,30}",
        description in prop_oneof![
            Just(json!(7)), Just(json!(true)), Just(json!(["Run it"])),
            Just(json!({ "text": "Run it" })), Just(json!(null)),
        ],
    ) {
        let with_other = json!({ field: detail, "description": description });
        let without = json!({ field: detail });

        let described = describe(tool_name, with_other, &task_folder)?;
        let plain = describe(tool_name, without, &task_folder)?;

        prop_assert_eq!(described.summary, plain.summary);
    }

    #[test]
    fn test_read_agent_description_property_names_the_task_folder(
        task_folder in any_task_folder(),
        words in "[A-Z][a-z ]{0,20}[a-z]",
        inner in "[a-z]{1,8}",
    ) {
        let description = format!("{words} in {task_folder}/{inner}");
        let input = json!({ "command": "ls", "description": description });

        let described = describe("Bash", input, &task_folder)?;

        let expected = format!("{words} in {TASK_FOLDER_NAME}/{inner}");
        prop_assert_eq!(described.summary, expected);
    }

    #[test]
    fn test_make_up_summary_property_file_tools_name_the_file(
        task_folder in any_task_folder(),
        (tool_name, field, verb) in any_file_tool(),
        folders in proptest::collection::vec("[a-z]{1,6}", 0..4),
        name in "[a-zA-Z0-9_-]{1,12}\\.[a-z]{1,4}",
    ) {
        let mut detail = task_folder.clone();
        for folder in &folders {
            detail.push('/');
            detail.push_str(folder);
        }
        detail.push('/');
        detail.push_str(&name);
        let input = json!({ field: detail });

        let described = describe(tool_name, input, &task_folder)?;

        prop_assert_eq!(described.summary, format!("{verb} {name}"));
    }

    #[test]
    fn test_make_up_summary_property_unknown_tools_are_used(
        task_folder in any_task_folder(),
        tool_name in "mcp__[a-z]{1,10}",
        input in proptest::collection::btree_map(
            "[a-z]{1,6}",
            "[a-z ]{0,10}",
            0..4,
        ),
    ) {
        let described = describe(&tool_name, json!(input), &task_folder)?;

        prop_assert_eq!(&described.summary, &format!("Use {tool_name}"));
        prop_assert_eq!(&described.command, &json!(input).to_string());
        prop_assert_eq!(described.tool, tool_name);
    }

    #[test]
    fn test_make_up_summary_property_is_always_one_short_line(
        task_folder in any_task_folder(),
        (tool_name, field, _) in prop_oneof![any_file_tool(), any_text_tool()],
        detail in "\\PC{0,200}",
        line_break in any_line_break(),
        rest in "\\PC{0,40}",
    ) {
        let input = json!({ field: format!("{detail}{line_break}{rest}") });

        let described = describe(tool_name, input, &task_folder)?;

        prop_assert!(!described.summary.is_empty());
        let summary = described.summary;
        prop_assert!(is_one_short_line(&summary), "{:?}", summary);
    }

    #[test]
    fn test_label_tool_use_property_text_tools_show_the_detail(
        task_folder in any_task_folder(),
        (tool_name, field, verb) in any_text_tool(),
        detail in "[a-z0-9][a-z0-9 .:*/-]{0,40}[a-z0-9]",
    ) {
        let input = json!({ field: detail });

        let described = describe(tool_name, input, &task_folder)?;

        prop_assert_eq!(described.summary, format!("{verb} {detail}"));
        prop_assert_eq!(described.command, detail);
    }

    #[test]
    fn test_label_tool_use_property_shell_commands_get_the_shell_label(
        task_folder in any_task_folder(),
        command in "[a-z]{1,8}( -{1,2}[a-z]{1,6}){0,3}( [a-z./]{1,9}){0,3}",
    ) {
        let input = json!({ "command": command });

        let described = describe("Bash", input, &task_folder)?;

        let label = label_shell_command(&command);
        prop_assert_eq!(described.summary, label.trim().to_owned());
    }

    #[test]
    fn test_label_tool_use_property_folder_like_details_keep_the_whole_path(
        task_folder in any_task_folder(),
        (tool_name, field, verb) in any_file_tool(),
        detail in prop_oneof![Just("/"), Just(".."), Just(""), Just("a/..")],
    ) {
        let input = json!({ field: detail });

        let described = describe(tool_name, input, &task_folder)?;

        let expected = format!("{verb} {detail}").trim().to_owned();
        prop_assert_eq!(described.summary, expected);
    }
}

proptest! {
    #[test]
    fn test_name_task_folder_property_sibling_folders_keep_their_names(
        task_folder in any_task_folder(),
        sibling_ending in prop_oneof![
            Just("0"), Just("-old"), Just(".bak"), Just("_copy"), Just("é"),
        ],
        inner in "[a-z]{1,8}",
    ) {
        let sibling = format!("{task_folder}{sibling_ending}/{inner}");
        let input = json!({ "command": format!("cat {sibling}") });

        let described = describe("Bash", input, &task_folder)?;

        prop_assert_eq!(described.command, format!("cat {sibling}"));
    }

    #[test]
    fn test_name_task_folder_property_text_without_the_folder_is_kept(
        task_folder in any_task_folder(),
        command in "\\PC{0,80}",
    ) {
        prop_assume!(!command.contains(&task_folder));
        let input = json!({ "command": command });

        let described = describe("Bash", input, &task_folder)?;

        prop_assert_eq!(described.command, command);
    }

    #[test]
    fn test_name_task_folder_property_every_mention_is_named(
        task_folder in any_task_folder(),
        separators in proptest::collection::vec(
            prop_oneof![Just(" "), Just("/"), Just("\""), Just(";"), Just("")],
            1..5,
        ),
    ) {
        let mut command = String::from("ls");
        let mut expected = String::from("ls");
        for separator in &separators {
            command.push(' ');
            command.push_str(&task_folder);
            command.push_str(separator);
            expected.push(' ');
            expected.push_str(TASK_FOLDER_NAME);
            expected.push_str(separator);
        }

        let input = json!({ "command": command });

        let described = describe("Bash", input, &task_folder)?;

        prop_assert_eq!(described.command, expected);
    }

    #[test]
    fn test_fit_on_one_line_property_keeps_only_the_first_line(
        task_folder in any_task_folder(),
        first in "[A-Z][a-z ]{0,30}[a-z]",
        line_break in any_line_break(),
        second in "[a-z ]{1,30}",
    ) {
        let description = format!("{first}{line_break}{second}");
        let input = json!({ "command": "ls", "description": description });

        let described = describe("Bash", input, &task_folder)?;

        prop_assert_eq!(described.summary, first);
    }

    #[test]
    fn test_fit_on_one_line_property_long_lines_are_cut_with_a_marker(
        task_folder in any_task_folder(),
        words in proptest::collection::vec("[a-z]{1,9}", 20..40),
    ) {
        let description = words.join(" ");
        let input = json!({ "command": "ls", "description": description });

        let described = describe("Bash", input, &task_folder)?;

        let kept = described.summary.trim_end_matches(SHORTENED_MARKER);
        prop_assert!(described.summary.ends_with(SHORTENED_MARKER));
        prop_assert!(description.starts_with(kept));
        prop_assert!(is_one_short_line(&described.summary));
    }

    #[test]
    fn test_fit_on_one_line_property_surrounding_space_is_trimmed(
        task_folder in any_task_folder(),
        before in "[ \t\n]{0,4}",
        words in "[A-Z][a-z ]{0,30}[a-z]",
        after in "[ \t]{0,4}",
    ) {
        let description = format!("{before}{words}{after}");
        let input = json!({ "command": "ls", "description": description });

        let described = describe("Bash", input, &task_folder)?;

        prop_assert_eq!(described.summary, words);
    }
}
