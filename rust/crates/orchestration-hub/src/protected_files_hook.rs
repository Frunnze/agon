use orchestration_core::protected_files::ProtectedFiles;
use serde_json::json;

use crate::protected_file_expressions::describe_protected_expression;

pub const REFUSAL_REASON: &str =
    "Agon refused: this file is on the list of files agents can't read.";
const NAMED_FIELDS_EXPRESSION: &str = concat!(
    r#""(command|file_path|path|glob|notebook_path)""#,
    r#"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*""#,
);
const HOME_NAMING_SCRIPT: &str = concat!(
    r#"awk -v home="$HOME/" '{ while (home != "/" && "#,
    r#"(at = index($0, home)) > 0) "#,
    r#"$0 = substr($0, 1, at - 1) "~/" substr($0, at + length(home)); "#,
    r#"print }'"#,
);
const HOME_VARIABLE_NAMING_SCRIPT: &str =
    r"sed 's#\$[{]\{0,1\}HOME[}]\{0,1\}/#~/#g'";
const PIPE: &str = " | ";
const LINE_BREAK: &str = "\n";
const SUCCESSFUL_EXIT: &str = "exit 0";

#[must_use]
pub fn write_protected_files_hook(protected: &ProtectedFiles) -> String {
    let fields_reading =
        format!("grep -oE {}", shell_words::quote(NAMED_FIELDS_EXPRESSION));
    let protected_expression = describe_protected_expression(protected);
    let protected_matching =
        format!("grep -qiE {}", shell_words::quote(&protected_expression));
    let refusal = format!(
        "printf '%s' {}",
        shell_words::quote(&describe_refusal_decision())
    );

    let checking_pipeline = [
        fields_reading.as_str(),
        HOME_NAMING_SCRIPT,
        HOME_VARIABLE_NAMING_SCRIPT,
        protected_matching.as_str(),
    ]
    .join(PIPE);
    let refusing_line = format!("{checking_pipeline} && {refusal}");
    [refusing_line.as_str(), SUCCESSFUL_EXIT].join(LINE_BREAK)
}

fn describe_refusal_decision() -> String {
    let decision = json!({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": REFUSAL_REASON,
        }
    });
    decision.to_string()
}
