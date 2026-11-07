use std::io::Write;
use std::process::{Command, Stdio};

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::hook_running::{
    Decision, HOOK_CASES, any_home, any_name, decide_tool, hook_for,
    read_refusal, to_case_error,
};

const SHELL_PROGRAM: &str = "sh";
const HOME_VARIABLE: &str = "HOME";
const GLOB_TOOL: &str = "Glob";
const GREP_TOOL: &str = "Grep";
const WORKSPACE_FOLDER: &str = "/workspace";

fn any_glob_ending() -> impl Strategy<Value = String> {
    prop_oneof![
        Just("*".to_owned()),
        Just("**".to_owned()),
        Just("**/*".to_owned()),
        Just("*.pem".to_owned()),
        "[a-z]{1,6}".prop_map(|name| format!("{name}*")),
    ]
}

fn any_home_spelling(home: String) -> impl Strategy<Value = String> {
    prop_oneof![Just("~".to_owned()), Just(home), Just("$HOME".to_owned()),]
}

fn decide_glob(hook: &str, home: &str, glob_input: &Value) -> Decision {
    decide_tool(hook, home, GLOB_TOOL, glob_input)
}

fn decide_tool_named_first(
    hook: &str,
    home: &str,
    tool_name: &str,
    tool_input: &Value,
) -> Decision {
    let hook_input =
        format!(r#"{{"tool_name":"{tool_name}","tool_input":{tool_input}}}"#);
    let mut child = Command::new(SHELL_PROGRAM)
        .arg("-c")
        .arg(hook)
        .env(HOME_VARIABLE, home)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .map_err(to_case_error)?;
    let mut input = child
        .stdin
        .take()
        .ok_or_else(|| to_case_error("the hook takes no input"))?;
    input
        .write_all(hook_input.as_bytes())
        .map_err(to_case_error)?;
    drop(input);

    let output = child.wait_with_output().map_err(to_case_error)?;
    read_refusal(&String::from_utf8_lossy(&output.stdout))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HOOK_CASES))]

    #[test]
    fn test_write_protected_files_hook_property_glob_into_protected_is_refused(
        (home, spelled_home) in any_home().prop_flat_map(|home| {
            (Just(home.clone()), any_home_spelling(home))
        }),
        folder in any_name(),
        ending in any_glob_ending(),
    ) {
        let hook = hook_for(&[format!("~/.{folder}")]);
        let pattern = format!("{spelled_home}/.{folder}/{ending}");

        let glob_input = json!({ "pattern": pattern });
        let is_refused = decide_glob(&hook, &home, &glob_input)?;
        let is_refused_named_first =
            decide_tool_named_first(&hook, &home, GLOB_TOOL, &glob_input)?;

        prop_assert!(is_refused, "{}", pattern);
        prop_assert!(is_refused_named_first, "{}", pattern);
    }

    #[test]
    fn test_write_protected_files_hook_property_glob_path_in_protected_refused(
        home in any_home(),
        folder in any_name(),
        ending in any_glob_ending(),
    ) {
        let hook = hook_for(&[format!("~/.{folder}")]);
        let path = format!("{home}/.{folder}");

        let glob_input = json!({ "pattern": ending, "path": path });
        let is_refused = decide_glob(&hook, &home, &glob_input)?;
        let elsewhere = json!({ "pattern": ending, "path": WORKSPACE_FOLDER });
        let is_elsewhere_refused = decide_glob(&hook, &home, &elsewhere)?;

        prop_assert!(is_refused);
        prop_assert!(!is_elsewhere_refused);
    }

    #[test]
    fn test_write_protected_files_hook_property_grep_pattern_is_only_text(
        home in any_home(),
        name in any_name(),
    ) {
        let protected_name = format!(".{name}");
        let hook = hook_for(std::slice::from_ref(&protected_name));

        let grep_input =
            json!({ "pattern": protected_name, "path": WORKSPACE_FOLDER });
        let is_grep_refused =
            decide_tool(&hook, &home, GREP_TOOL, &grep_input)?;
        let is_grep_named_first_refused =
            decide_tool_named_first(&hook, &home, GREP_TOOL, &grep_input)?;
        let glob_input = json!({ "pattern": format!("**/{protected_name}") });
        let is_glob_refused = decide_glob(&hook, &home, &glob_input)?;

        prop_assert!(!is_grep_refused);
        prop_assert!(!is_grep_named_first_refused);
        prop_assert!(is_glob_refused);
    }
}
