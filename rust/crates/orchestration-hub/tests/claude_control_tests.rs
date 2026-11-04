use orchestration_core::approval::ApprovalDecision;
use orchestration_hub::claude_control::{
    ClaudeControlLine, ToolPermissionRequest, read_control_line,
    write_interrupt_request, write_permission_answer, write_user_message,
};
use proptest::prelude::*;
use serde_json::{Value, json};

const OBSERVED_REQUEST: &str = concat!(
    r#"{"type":"control_request","request_id":"311452ce","#,
    r#""request":{"subtype":"can_use_tool","tool_name":"Bash","#,
    r#""display_name":"Bash","input":{"command":"echo hi > hi.txt","#,
    r#""description":"Write hi to hi.txt"},"permission_suggestions":[],"#,
    r#""tool_use_id":"toolu_01"}}"#,
);
const OBSERVED_RESULT: &str = concat!(
    r#"{"duration_api_ms":5796,"stop_reason":"end_turn","#,
    r#""session_id":"ed60f018","type":"result","subtype":"success","#,
    r#""is_error":false,"result":"hi"}"#,
);
const DENIED_MESSAGE: &str = "The person denied this command.";
const OBSERVED_INTERRUPT_ANSWER: &str = concat!(
    r#"{"type":"control_response","response":{"subtype":"success","#,
    r#""request_id":"interrupt-1","response":{"still_queued":[]}}}"#,
);
const INTERRUPTED_RESULT: &str = concat!(
    r#"{"duration_api_ms":0,"stop_reason":null,"is_error":true,"#,
    r#""num_turns":2,"subtype":"error_during_execution","type":"result"}"#,
);

fn any_request_id() -> impl Strategy<Value = String> {
    "[A-Za-z0-9_-]{1,40}"
}

fn answer_control_request(request_line: &str, subtype: &str) -> String {
    let request = parse_json(request_line);
    json!({
        "type": "control_response",
        "response": {
            "subtype": subtype,
            "request_id": request["request_id"],
            "response": {},
        },
    })
    .to_string()
}

fn any_input() -> impl Strategy<Value = Value> {
    prop_oneof![
        "\\PC{0,60}".prop_map(|command| json!({"command": command})),
        ("\\PC{0,60}", "\\PC{0,60}").prop_map(|(path, text)| {
            json!({"file_path": path, "content": text})
        }),
        Just(json!({})),
    ]
}

fn any_request() -> impl Strategy<Value = ToolPermissionRequest> {
    ("[a-f0-9-]{1,36}", "[A-Za-z_]{1,20}", any_input()).prop_map(
        |(request_id, tool_name, input)| ToolPermissionRequest {
            request_id,
            tool_name,
            input,
        },
    )
}

fn render_request(request: &ToolPermissionRequest) -> String {
    json!({
        "type": "control_request",
        "request_id": request.request_id,
        "request": {
            "subtype": "can_use_tool",
            "tool_name": request.tool_name,
            "input": request.input,
            "tool_use_id": "toolu_1",
        },
    })
    .to_string()
}

fn parse_json(text: &str) -> Value {
    serde_json::from_str(text).unwrap_or(Value::Null)
}

#[test]
fn reads_the_permission_request_claude_code_sends() {
    let line = read_control_line(OBSERVED_REQUEST);

    let expected = ToolPermissionRequest {
        request_id: "311452ce".to_string(),
        tool_name: "Bash".to_string(),
        input: json!({
            "command": "echo hi > hi.txt",
            "description": "Write hi to hi.txt",
        }),
    };
    assert_eq!(line, ClaudeControlLine::PermissionRequest(expected));
}

#[test]
fn reads_the_result_message_as_the_end_of_the_turn() {
    let line = read_control_line(OBSERVED_RESULT);

    assert_eq!(line, ClaudeControlLine::TurnEnded);
}

#[test]
fn ignores_control_requests_that_ask_for_something_else() {
    let line = json!({
        "type": "control_request",
        "request_id": "1",
        "request": {"subtype": "hook_callback", "callback_id": "a"},
    })
    .to_string();

    assert_eq!(read_control_line(&line), ClaudeControlLine::Other);
}

#[test]
fn reads_the_interrupt_answer_claude_code_sends() {
    let line = read_control_line(OBSERVED_INTERRUPT_ANSWER);

    let expected = ClaudeControlLine::RequestAnswered("interrupt-1".into());
    assert_eq!(line, expected);
}

#[test]
fn reads_the_interrupted_turns_result_as_the_end_of_the_turn() {
    let line = read_control_line(INTERRUPTED_RESULT);

    assert_eq!(line, ClaudeControlLine::TurnEnded);
}

#[test]
fn writes_the_interrupt_request_claude_code_answers() {
    let request = write_interrupt_request("interrupt-1");

    let expected = json!({
        "type": "control_request",
        "request_id": "interrupt-1",
        "request": {"subtype": "interrupt"},
    });
    assert_eq!(parse_json(&request), expected);
}

proptest! {
    #[test]
    fn test_write_interrupt_request_property_asks_to_interrupt_with_the_id(
        request_id in any_request_id(),
    ) {
        let request = write_interrupt_request(&request_id);

        let expected = json!({
            "type": "control_request",
            "request_id": request_id,
            "request": {"subtype": "interrupt"},
        });
        prop_assert!(!request.contains('\n'));
        prop_assert_eq!(parse_json(&request), expected);
    }

    #[test]
    fn test_write_interrupt_request_property_answer_reads_back_the_same_id(
        request_id in any_request_id(),
        subtype in prop_oneof![Just("success"), Just("error")],
    ) {
        let request = write_interrupt_request(&request_id);
        let answer = answer_control_request(&request, subtype);

        let line = read_control_line(&answer);

        prop_assert_eq!(line, ClaudeControlLine::RequestAnswered(request_id));
    }

    #[test]
    fn test_write_interrupt_request_property_is_never_read_as_a_request(
        request_id in any_request_id(),
    ) {
        let request = write_interrupt_request(&request_id);

        prop_assert_eq!(read_control_line(&request), ClaudeControlLine::Other);
    }

    #[test]
    fn test_read_control_line_property_answers_keep_their_request_id(
        request_id in any_request_id(),
        subtype in prop_oneof![Just("success"), Just("error")],
    ) {
        let answer = json!({
            "type": "control_response",
            "response": {"subtype": subtype, "request_id": request_id},
        })
        .to_string();

        let line = read_control_line(&answer);

        prop_assert_eq!(line, ClaudeControlLine::RequestAnswered(request_id));
    }
}

proptest! {
    #[test]
    fn test_read_control_line_property_keeps_every_request_detail(
        request in any_request(),
    ) {
        let line = read_control_line(&render_request(&request));

        prop_assert_eq!(line, ClaudeControlLine::PermissionRequest(request));
    }

    #[test]
    fn test_read_control_line_property_other_messages_are_not_control(
        text in "\\PC{0,40}",
        message_type in prop_oneof![
            Just("assistant"),
            Just("user"),
            Just("system"),
        ],
    ) {
        let line = json!({"type": message_type, "message": text}).to_string();

        prop_assert_eq!(read_control_line(&line), ClaudeControlLine::Other);
    }

    #[test]
    fn test_read_control_line_fuzz_arbitrary_text_is_never_a_request(
        text in "\\PC{0,200}",
    ) {
        let line = read_control_line(&text);

        let is_request =
            matches!(line, ClaudeControlLine::PermissionRequest(_));
        prop_assert!(!is_request);
    }

    #[test]
    fn test_write_permission_answer_property_approval_allows_same_input(
        request in any_request(),
    ) {
        let answer =
            write_permission_answer(&request, ApprovalDecision::Approved);

        let expected = json!({
            "type": "control_response",
            "response": {
                "subtype": "success",
                "request_id": request.request_id,
                "response": {
                    "behavior": "allow",
                    "updatedInput": request.input,
                },
            },
        });
        prop_assert!(!answer.contains('\n'));
        prop_assert_eq!(parse_json(&answer), expected);
    }

    #[test]
    fn test_write_permission_answer_property_denial_tells_the_agent_why(
        request in any_request(),
    ) {
        let answer =
            write_permission_answer(&request, ApprovalDecision::Denied);

        let expected = json!({
            "type": "control_response",
            "response": {
                "subtype": "success",
                "request_id": request.request_id,
                "response": {
                    "behavior": "deny",
                    "message": DENIED_MESSAGE,
                },
            },
        });
        prop_assert!(!answer.contains('\n'));
        prop_assert_eq!(parse_json(&answer), expected);
    }

    #[test]
    fn test_write_user_message_property_carries_the_exact_prompt(
        prompt in "\\PC{0,200}(\n\\PC{0,40}){0,3}",
    ) {
        let message = write_user_message(&prompt);

        let expected = json!({
            "type": "user",
            "message": {"role": "user", "content": prompt},
        });
        prop_assert!(!message.contains('\n'));
        prop_assert_eq!(parse_json(&message), expected);
    }
}
