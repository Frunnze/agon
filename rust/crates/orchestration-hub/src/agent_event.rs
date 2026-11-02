use orchestration_core::approval::ApprovalAction;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum AgentEvent {
    Said(String),
    UsedTool(String),
    ToolFailed(String),
    Finished,
    Failed(String),
    SessionStarted(String),
    AskedForApproval(ApprovalAction),
}
