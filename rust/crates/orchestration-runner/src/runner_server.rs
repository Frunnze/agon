use orchestration_api::work::{
    ClaimResponse, CreateApprovalRequest, HeartbeatRequest, RunEventsRequest,
};
use orchestration_core::approval::ApprovalDecision;
use orchestration_core::identifiers::RunId;
use orchestration_core::run::ChatMessage;
use thiserror::Error;

#[derive(Clone, Debug, PartialEq, Eq, Error)]
#[error("the app server request failed: {reason}")]
pub struct ServerError {
    pub reason: String,
}

pub trait RunnerServer: Send + Sync + 'static {
    fn send_heartbeat(
        &self,
        heartbeat: &HeartbeatRequest,
    ) -> impl Future<Output = Result<(), ServerError>> + Send;

    fn claim_next_run(
        &self,
    ) -> impl Future<Output = Result<ClaimResponse, ServerError>> + Send;

    fn post_run_events(
        &self,
        run_id: RunId,
        events: &RunEventsRequest,
    ) -> impl Future<Output = Result<(), ServerError>> + Send;

    fn request_approval_decision(
        &self,
        request: &CreateApprovalRequest,
    ) -> impl Future<Output = Result<ApprovalDecision, ServerError>> + Send;

    fn read_user_messages(
        &self,
        run_id: RunId,
    ) -> impl Future<Output = Result<Vec<ChatMessage>, ServerError>> + Send;

    fn is_run_cancelled(
        &self,
        run_id: RunId,
    ) -> impl Future<Output = Result<bool, ServerError>> + Send;
}
