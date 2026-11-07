use std::path::Path;

use orchestration_hub::workspace_mounts::CONTAINER_WORKSPACE_DIRECTORY;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::hook_running::{
    HOOK_CASES, any_home, any_name, decide_command, decide_read, hook_for,
    read_refusal, run_hook, to_case_error,
};

const TARGET_TEMPORARY_FOLDER: &str = env!("CARGO_TARGET_TMPDIR");
const MARKER_FOLDER_PREFIX: &str = "protection-hook-marker-";
const MARKER_FILE_NAME: &str = "ran";

fn any_shell_word() -> impl Strategy<Value = String> {
    prop_oneof![
        Just("`touch MARKER`".to_owned()),
        Just("$(touch MARKER)".to_owned()),
        Just("; touch MARKER;".to_owned()),
        Just("&& touch MARKER".to_owned()),
        Just("| touch MARKER".to_owned()),
        Just("' ; touch MARKER ; '".to_owned()),
        Just("\" ; touch MARKER ; \"".to_owned()),
        Just("> MARKER".to_owned()),
        Just("$HOME".to_owned()),
        Just("!#*?~".to_owned()),
    ]
}

fn any_nameless_pattern() -> impl Strategy<Value = String> {
    prop_oneof![
        Just("~".to_owned()),
        Just("/".to_owned()),
        Just(".".to_owned()),
        Just("./.".to_owned()),
        Just("~/./".to_owned()),
        Just("//".to_owned()),
    ]
}

fn place_marker(word: &str, marker: &Path) -> String {
    word.replace("MARKER", &marker.display().to_string())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HOOK_CASES))]

    #[test]
    fn test_write_protected_files_hook_property_patterns_never_run_as_shell(
        before in any_name(),
        word in any_shell_word(),
        home in any_home(),
    ) {
        let marker_folder = tempfile::Builder::new()
            .prefix(MARKER_FOLDER_PREFIX)
            .tempdir_in(TARGET_TEMPORARY_FOLDER)
            .map_err(to_case_error)?;
        let marker = marker_folder.path().join(MARKER_FILE_NAME);
        let pattern = format!("{before}{}", place_marker(&word, &marker));
        let hook = hook_for(std::slice::from_ref(&pattern));

        let path = format!("{CONTAINER_WORKSPACE_DIRECTORY}/notes.txt");
        let _decision = decide_read(&hook, &home, &path)?;
        let _command = decide_command(&hook, &home, &format!("ls {before}"))?;

        prop_assert!(!marker.exists());
    }

    #[test]
    fn test_describe_protected_expression_property_nameless_refuse_nothing(
        patterns in proptest::collection::vec(any_nameless_pattern(), 1..4),
        name in any_name(),
        home in any_home(),
    ) {
        let hook = hook_for(&patterns);

        let file_path = format!("{home}/{name}");
        let command = format!("cat {file_path}");

        prop_assert!(!decide_read(&hook, &home, &file_path)?);
        prop_assert!(!decide_command(&hook, &home, &command)?);
    }

    #[test]
    fn test_describe_refusal_decision_property_prints_one_whole_decision(
        name in any_name(),
        home in any_home(),
        tool_name in prop_oneof![Just("Read"), Just("Edit"), Just("Write")],
    ) {
        let hook = hook_for(std::slice::from_ref(&name));
        let file_path = format!("{CONTAINER_WORKSPACE_DIRECTORY}/{name}");
        let tool_input = json!({ "file_path": file_path });

        let hook_output = run_hook(&hook, &home, tool_name, &tool_input)?;
        let decision: Value =
            serde_json::from_str(&hook_output).map_err(to_case_error)?;

        prop_assert!(read_refusal(&hook_output)?);
        let field_count = decision.as_object().map(serde_json::Map::len);
        prop_assert_eq!(field_count, Some(1));
        prop_assert!(!hook_output.contains('\n'));
    }

    #[test]
    fn test_describe_refusal_decision_property_same_for_every_refused_tool(
        name in any_name(),
        home in any_home(),
    ) {
        let hook = hook_for(std::slice::from_ref(&name));
        let file_path = format!("{CONTAINER_WORKSPACE_DIRECTORY}/{name}");

        let read_input = json!({ "file_path": file_path });
        let read_output = run_hook(&hook, &home, "Read", &read_input)?;
        let command_output = run_hook(
            &hook,
            &home,
            "Bash",
            &json!({ "command": format!("cat {file_path}") }),
        )?;

        prop_assert!(!read_output.is_empty());
        prop_assert_eq!(read_output, command_output);
    }

    #[test]
    fn test_describe_refusal_decision_property_allowed_use_prints_nothing(
        name in any_name(),
        other in any_name(),
        home in any_home(),
    ) {
        prop_assume!(name != other);
        let hook = hook_for(&[name]);
        let file_path = format!("{CONTAINER_WORKSPACE_DIRECTORY}/{other}");

        let read_input = json!({ "file_path": file_path });
        let hook_output = run_hook(&hook, &home, "Read", &read_input)?;

        prop_assert_eq!(hook_output, "");
    }
}
