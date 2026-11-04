use orchestration_core::approval::ApprovalDecision;
use serde::Deserialize;
use serde_json::{Value, json};

const USER_LINE_TYPE: &str = "user";
const USER_ROLE: &str = "user";
const CONTROL_REQUEST_TYPE: &str = "control_request";
const CONTROL_RESPONSE_TYPE: &str = "control_response";
const INTERRUPT_SUBTYPE: &str = "interrupt";
const SUCCESS_SUBTYPE: &str = "success";
const ALLOW_BEHAVIOR: &str = "allow";
const DENY_BEHAVIOR: &str = "deny";
const DENIED_COMMAND_MESSAGE: &str = "The person denied this command.";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ToolPermissionRequest {
    pub request_id: String,
    pub tool_name: String,
    pub input: Value,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ClaudeControlLine {
    PermissionRequest(ToolPermissionRequest),
    RequestAnswered(String),
    TurnEnded,
    Other,
}

#[derive(Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum ClaudeOutputLine {
    ControlRequest {
        request_id: String,
        request: ClaudeControlRequest,
    },
    ControlResponse {
        response: ClaudeControlAnswer,
    },
    Result {},
}

#[derive(Deserialize)]
struct ClaudeControlAnswer {
    request_id: String,
}

#[derive(Deserialize)]
#[serde(tag = "subtype", rename_all = "snake_case")]
enum ClaudeControlRequest {
    CanUseTool {
        tool_name: String,
        #[serde(default)]
        input: Value,
    },
}

#[must_use]
pub fn read_control_line(line: &str) -> ClaudeControlLine {
    let Ok(output_line) = serde_json::from_str::<ClaudeOutputLine>(line)
    else {
        return ClaudeControlLine::Other;
    };

    match output_line {
        ClaudeOutputLine::ControlRequest {
            request_id,
            request: ClaudeControlRequest::CanUseTool { tool_name, input },
        } => ClaudeControlLine::PermissionRequest(ToolPermissionRequest {
            request_id,
            tool_name,
            input,
        }),
        ClaudeOutputLine::ControlResponse { response } => {
            ClaudeControlLine::RequestAnswered(response.request_id)
        }
        ClaudeOutputLine::Result {} => ClaudeControlLine::TurnEnded,
    }
}

#[must_use]
pub fn write_interrupt_request(request_id: &str) -> String {
    let request = json!({
        "type": CONTROL_REQUEST_TYPE,
        "request_id": request_id,
        "request": {"subtype": INTERRUPT_SUBTYPE},
    });
    request.to_string()
}

#[must_use]
pub fn write_user_message(prompt: &str) -> String {
    let message = json!({
        "type": USER_LINE_TYPE,
        "message": {"role": USER_ROLE, "content": prompt},
    });
    message.to_string()
}

#[must_use]
pub fn write_permission_answer(
    request: &ToolPermissionRequest,
    decision: ApprovalDecision,
) -> String {
    let permission = match decision {
        ApprovalDecision::Approved => json!({
            "behavior": ALLOW_BEHAVIOR,
            "updatedInput": request.input,
        }),
        ApprovalDecision::Denied => json!({
            "behavior": DENY_BEHAVIOR,
            "message": DENIED_COMMAND_MESSAGE,
        }),
    };
    let answer = json!({
        "type": CONTROL_RESPONSE_TYPE,
        "response": {
            "subtype": SUCCESS_SUBTYPE,
            "request_id": request.request_id,
            "response": permission,
        },
    });
    answer.to_string()
}
