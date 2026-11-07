use orchestration_core::approval::ApprovalDecision;
use orchestration_hub::claude_control::{
    ClaudeControlLine, ToolPermissionRequest, read_control_line,
    write_permission_answer, write_user_message,
};
use proptest::prelude::*;
use serde_json::json;

const LINE_ENDS: [char; 2] = ['\n', '\r'];

fn any_prompt() -> impl Strategy<Value = String> {
    prop_oneof![
        any::<String>(),
        "[a-z \n\r\t\u{2028}\u{85}\"\\\\{}]{0,40}",
        Just(r#"{"type":"control_request","request_id":"1"}"#.to_owned()),
    ]
}

fn any_decision() -> impl Strategy<Value = ApprovalDecision> {
    prop_oneof![
        Just(ApprovalDecision::Approved),
        Just(ApprovalDecision::Denied),
    ]
}

fn any_request() -> impl Strategy<Value = ToolPermissionRequest> {
    (any::<String>(), "[A-Za-z_]{1,12}", any::<String>()).prop_map(
        |(request_id, tool_name, command)| ToolPermissionRequest {
            request_id,
            tool_name,
            input: json!({"command": command}),
        },
    )
}

proptest! {
    #[test]
    fn test_write_user_message_property_is_one_line_for_any_prompt(
        prompt in any_prompt(),
    ) {
        let message = write_user_message(&prompt);

        prop_assert!(!message.contains(LINE_ENDS));
    }

    #[test]
    fn test_write_user_message_property_is_never_read_as_control(
        prompt in any_prompt(),
    ) {
        let message = write_user_message(&prompt);

        prop_assert_eq!(read_control_line(&message), ClaudeControlLine::Other);
    }

    #[test]
    fn test_write_permission_answer_property_answers_the_same_request(
        request in any_request(),
        decision in any_decision(),
    ) {
        let answer = write_permission_answer(&request, decision);

        prop_assert!(!answer.contains(LINE_ENDS));
        let expected = ClaudeControlLine::RequestAnswered(request.request_id);
        prop_assert_eq!(read_control_line(&answer), expected);
    }
}
