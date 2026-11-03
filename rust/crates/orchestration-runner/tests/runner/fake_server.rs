use std::collections::VecDeque;
use std::future::{pending, ready};
use std::sync::Mutex;

use chrono::DateTime;
use orchestration_api::catalog::ImproveSkillRequest;
use orchestration_api::work::{
    ClaimResponse, CreateApprovalRequest, ForgottenWork, HeartbeatRequest,
    RunAssignment, RunEvent, RunEventsRequest,
};
use orchestration_core::approval::ApprovalDecision;
use orchestration_core::identifiers::{RunId, SkillId};
use orchestration_core::run::{ChatAuthor, ChatMessage};
use orchestration_runner::runner_server::{RunnerServer, ServerError};

use crate::support::hold;

#[derive(Clone, Copy, Debug)]
pub enum ApprovalAnswer {
    Decide(ApprovalDecision),
    NeverDecide,
}

#[derive(Clone, Debug)]
pub enum CancellationRule {
    Never,
    WhenLogContains(String),
    WhenApprovalRequested,
}

#[derive(Debug, Default)]
struct RecordedState {
    queued_assignments: VecDeque<RunAssignment>,
    heartbeats: Vec<HeartbeatRequest>,
    events: Vec<(RunId, RunEvent)>,
    approval_requests: Vec<CreateApprovalRequest>,
    skill_proposals: Vec<(SkillId, ImproveSkillRequest)>,
}

#[derive(Debug)]
pub struct FakeServer {
    approval_answer: ApprovalAnswer,
    cancellation_rule: CancellationRule,
    user_messages: Vec<ChatMessage>,
    forgotten_work: ForgottenWork,
    is_refusing_skill_proposals: bool,
    state: Mutex<RecordedState>,
}

impl FakeServer {
    pub fn with_queue(assignments: Vec<RunAssignment>) -> Self {
        let state = RecordedState {
            queued_assignments: assignments.into(),
            ..RecordedState::default()
        };
        Self {
            approval_answer: ApprovalAnswer::Decide(
                ApprovalDecision::Approved,
            ),
            cancellation_rule: CancellationRule::Never,
            user_messages: Vec::new(),
            forgotten_work: ForgottenWork::default(),
            is_refusing_skill_proposals: false,
            state: Mutex::new(state),
        }
    }

    pub fn answering_approvals(self, approval_answer: ApprovalAnswer) -> Self {
        Self {
            approval_answer,
            ..self
        }
    }

    pub fn cancelling(self, cancellation_rule: CancellationRule) -> Self {
        Self {
            cancellation_rule,
            ..self
        }
    }

    pub fn with_user_messages(self, texts: &[&str]) -> Self {
        let mut user_messages = Vec::new();
        for text in texts {
            user_messages.push(ChatMessage {
                at: DateTime::UNIX_EPOCH,
                author: ChatAuthor::You,
                text: (*text).to_string(),
                is_error: false,
                waiting_to_send: true,
            });
        }
        Self {
            user_messages,
            ..self
        }
    }

    pub fn forgetting(self, forgotten_work: ForgottenWork) -> Self {
        Self {
            forgotten_work,
            ..self
        }
    }

    pub fn refusing_skill_proposals(self) -> Self {
        Self {
            is_refusing_skill_proposals: true,
            ..self
        }
    }

    pub fn skill_proposals(&self) -> Vec<(SkillId, ImproveSkillRequest)> {
        hold(&self.state).skill_proposals.clone()
    }

    pub fn heartbeats(&self) -> Vec<HeartbeatRequest> {
        hold(&self.state).heartbeats.clone()
    }

    pub fn events_of(&self, run_id: RunId) -> Vec<RunEvent> {
        let mut run_events = Vec::new();
        for (event_run_id, event) in &hold(&self.state).events {
            if *event_run_id == run_id {
                run_events.push(event.clone());
            }
        }
        run_events
    }

    pub fn approval_requests(&self) -> Vec<CreateApprovalRequest> {
        hold(&self.state).approval_requests.clone()
    }

    pub fn queued_count(&self) -> usize {
        hold(&self.state).queued_assignments.len()
    }

    fn is_cancelled_now(&self, run_id: RunId) -> bool {
        let state = hold(&self.state);
        match &self.cancellation_rule {
            CancellationRule::Never => false,
            CancellationRule::WhenLogContains(text) => {
                state.events.iter().any(|(event_run_id, event)| {
                    *event_run_id == run_id && logs_text(event, text)
                })
            }
            CancellationRule::WhenApprovalRequested => state
                .approval_requests
                .iter()
                .any(|request| request.run_id == Some(run_id)),
        }
    }
}

fn logs_text(event: &RunEvent, text: &str) -> bool {
    match event {
        RunEvent::LogAppended { line } => line.text.contains(text),
        _ => false,
    }
}

impl RunnerServer for FakeServer {
    fn send_heartbeat(
        &self,
        heartbeat: &HeartbeatRequest,
    ) -> impl Future<Output = Result<ForgottenWork, ServerError>> + Send {
        hold(&self.state).heartbeats.push(heartbeat.clone());
        ready(Ok(self.forgotten_work.clone()))
    }

    fn claim_next_run(
        &self,
    ) -> impl Future<Output = Result<ClaimResponse, ServerError>> + Send {
        let assignment = hold(&self.state).queued_assignments.pop_front();
        ready(Ok(ClaimResponse { assignment }))
    }

    fn post_run_events(
        &self,
        run_id: RunId,
        events: &RunEventsRequest,
    ) -> impl Future<Output = Result<(), ServerError>> + Send {
        let mut state = hold(&self.state);
        for event in &events.events {
            state.events.push((run_id, event.clone()));
        }
        ready(Ok(()))
    }

    async fn request_approval_decision(
        &self,
        request: &CreateApprovalRequest,
    ) -> Result<ApprovalDecision, ServerError> {
        hold(&self.state).approval_requests.push(request.clone());
        match self.approval_answer {
            ApprovalAnswer::Decide(decision) => Ok(decision),
            ApprovalAnswer::NeverDecide => pending().await,
        }
    }

    fn propose_skill_improvement(
        &self,
        skill_id: SkillId,
        proposal: &ImproveSkillRequest,
    ) -> impl Future<Output = Result<(), ServerError>> + Send {
        let proposed = (skill_id, proposal.clone());
        hold(&self.state).skill_proposals.push(proposed);
        if self.is_refusing_skill_proposals {
            let reason = "agents may not improve this skill".to_owned();
            return ready(Err(ServerError { reason }));
        }
        ready(Ok(()))
    }

    fn read_user_messages(
        &self,
        _run_id: RunId,
    ) -> impl Future<Output = Result<Vec<ChatMessage>, ServerError>> + Send
    {
        ready(Ok(self.user_messages.clone()))
    }

    fn is_run_cancelled(
        &self,
        run_id: RunId,
    ) -> impl Future<Output = Result<bool, ServerError>> + Send {
        ready(Ok(self.is_cancelled_now(run_id)))
    }
}
