use std::collections::BTreeMap;
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};

use orchestration_api::catalog::ImproveSkillRequest;
use orchestration_api::work::{
    ClaimResponse, CreateApprovalRequest, ForgottenWork, HeartbeatRequest,
    RunEvent, RunEventsRequest,
};
use orchestration_core::approval::ApprovalDecision;
use orchestration_core::identifiers::{RunId, SkillId, WorkspaceId};
use orchestration_core::peer_address::ENDPOINT_PUBLIC_KEY_LENGTH;
use orchestration_core::run::{ChatAuthor, ChatMessage, RunStatus};
use orchestration_runner::runner_server::{RunnerServer, ServerError};
use orchestration_security::sealing::seal_text;
use tokio::sync::broadcast;

use super::approval_waiting::wait_for_decision;
use super::file_readers::{check_file_reader, find_device_with_peer_key};
use crate::content_sealing::{
    open_chat_message, open_run_assignment, seal_run_event,
};
use crate::device_roles::can_decide_approvals;
use crate::live_link_messages::RepositoryReference;
use crate::node::Node;
use crate::node_error::NodeError;

type RunWorkspaces = BTreeMap<RunId, WorkspaceId>;

const LIVE_FEED_CAPACITY: usize = 256;

#[derive(Clone, Debug)]
pub(crate) struct LiveUpdate {
    pub(crate) run_id: RunId,
    pub(crate) events: Vec<RunEvent>,
}

#[derive(Debug)]
pub struct NodeRunnerServer {
    node: Arc<Node>,
    claimed_run_workspaces: Mutex<RunWorkspaces>,
    live_feed: broadcast::Sender<LiveUpdate>,
}

impl NodeRunnerServer {
    #[must_use]
    pub fn new(node: Arc<Node>) -> Self {
        let (live_feed, _first_receiver) =
            broadcast::channel(LIVE_FEED_CAPACITY);
        Self {
            node,
            claimed_run_workspaces: Mutex::new(RunWorkspaces::new()),
            live_feed,
        }
    }

    pub(crate) fn subscribe_to_live_updates(
        &self,
    ) -> broadcast::Receiver<LiveUpdate> {
        self.live_feed.subscribe()
    }

    pub(crate) async fn authorize_watcher(
        &self,
        run_id: RunId,
        watcher_key: &[u8; ENDPOINT_PUBLIC_KEY_LENGTH],
    ) -> Result<(), NodeError> {
        let workspace_id = self.find_claimed_workspace(run_id)?;
        let session = self.node.open_session()?;
        let devices = session.client().list_devices().await?;
        let watcher = find_device_with_peer_key(&devices, watcher_key)
            .ok_or(NodeError::UntrustedPeer)?;
        let is_trusted_client = !watcher.revoked
            && can_decide_approvals(watcher.role)
            && watcher.workspaces.contains(&workspace_id);
        if !is_trusted_client {
            return Err(NodeError::UntrustedPeer);
        }
        Ok(())
    }

    pub(crate) async fn authorize_file_reader(
        &self,
        repository: &RepositoryReference,
        reader_key: &[u8; ENDPOINT_PUBLIC_KEY_LENGTH],
    ) -> Result<(), NodeError> {
        let session = self.node.open_session()?;
        let client = session.client();
        let devices = client.list_devices().await?;
        let projects = client.list_projects().await?;
        check_file_reader(&devices, &projects, reader_key, repository)
    }

    async fn announce(
        &self,
        heartbeat: &HeartbeatRequest,
    ) -> Result<ForgottenWork, NodeError> {
        let session = self.node.open_session()?;
        let forgotten_work =
            session.client().send_heartbeat(heartbeat).await?;
        self.node.refresh_server_group(&session).await?;
        Ok(forgotten_work)
    }

    async fn claim(&self) -> Result<ClaimResponse, NodeError> {
        let session = self.node.open_session()?;
        let response = session.client().claim_run().await?;
        let Some(sealed_assignment) = response.assignment else {
            return Ok(ClaimResponse { assignment: None });
        };

        let assignment =
            open_run_assignment(&session.keyring, &sealed_assignment)?;
        let workspace_id = assignment.workspace_id;
        self.lock_workspaces()
            .insert(assignment.run.id, workspace_id);
        Ok(ClaimResponse {
            assignment: Some(assignment),
        })
    }

    async fn post_sealed(
        &self,
        run_id: RunId,
        events: &RunEventsRequest,
    ) -> Result<(), NodeError> {
        let workspace_id = self.find_claimed_workspace(run_id)?;
        let session = self.node.open_session()?;
        let workspace_key = session.keyring.key_for(workspace_id)?;

        let mut sealed_events = Vec::new();
        for event in &events.events {
            sealed_events.push(seal_run_event(workspace_key, event)?);
        }
        let request = RunEventsRequest {
            events: sealed_events,
        };
        session.client().send_run_events(run_id, &request).await?;
        let update = LiveUpdate {
            run_id,
            events: events.events.clone(),
        };
        let _watcher_count = self.live_feed.send(update).unwrap_or_default();
        Ok(())
    }

    async fn hand_over_sealed_improvement(
        &self,
        skill_id: SkillId,
        proposal: &ImproveSkillRequest,
    ) -> Result<(), NodeError> {
        let workspace_id = self.find_claimed_workspace(proposal.run_id)?;
        let session = self.node.open_session()?;
        let workspace_key = session.keyring.key_for(workspace_id)?;
        let sealed_proposal = ImproveSkillRequest {
            instructions: seal_text(workspace_key, &proposal.instructions)?,
            ..proposal.clone()
        };
        let client = session.client();
        client.improve_skill(skill_id, &sealed_proposal).await
    }

    async fn read_opened_user_messages(
        &self,
        run_id: RunId,
    ) -> Result<Vec<ChatMessage>, NodeError> {
        let session = self.node.open_session()?;
        let run = session.client().read_run(run_id).await?;

        let mut user_messages = Vec::new();
        for message in &run.chat {
            if message.author == ChatAuthor::You {
                let opened = open_chat_message(&session.keyring, message)?;
                user_messages.push(opened);
            }
        }
        Ok(user_messages)
    }

    async fn read_cancellation(
        &self,
        run_id: RunId,
    ) -> Result<bool, NodeError> {
        let session = self.node.open_session()?;
        let run = session.client().read_run(run_id).await?;
        Ok(run.status == RunStatus::Cancelled)
    }

    fn find_claimed_workspace(
        &self,
        run_id: RunId,
    ) -> Result<WorkspaceId, NodeError> {
        let workspaces = self.lock_workspaces();
        let workspace_id = workspaces.get(&run_id).copied();
        workspace_id.ok_or_else(|| NodeError::NotFound {
            kind: "claimed run",
            identifier: run_id.0.to_string(),
        })
    }

    fn lock_workspaces(&self) -> MutexGuard<'_, RunWorkspaces> {
        self.claimed_run_workspaces
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
    }
}

impl RunnerServer for NodeRunnerServer {
    async fn send_heartbeat(
        &self,
        heartbeat: &HeartbeatRequest,
    ) -> Result<ForgottenWork, ServerError> {
        self.announce(heartbeat).await.map_err(ServerError::from)
    }

    async fn claim_next_run(&self) -> Result<ClaimResponse, ServerError> {
        self.claim().await.map_err(ServerError::from)
    }

    async fn post_run_events(
        &self,
        run_id: RunId,
        events: &RunEventsRequest,
    ) -> Result<(), ServerError> {
        self.post_sealed(run_id, events)
            .await
            .map_err(ServerError::from)
    }

    async fn request_approval_decision(
        &self,
        request: &CreateApprovalRequest,
    ) -> Result<ApprovalDecision, ServerError> {
        wait_for_decision(&self.node, request)
            .await
            .map_err(ServerError::from)
    }

    async fn propose_skill_improvement(
        &self,
        skill_id: SkillId,
        proposal: &ImproveSkillRequest,
    ) -> Result<(), ServerError> {
        self.hand_over_sealed_improvement(skill_id, proposal)
            .await
            .map_err(ServerError::from)
    }

    async fn read_user_messages(
        &self,
        run_id: RunId,
    ) -> Result<Vec<ChatMessage>, ServerError> {
        self.read_opened_user_messages(run_id)
            .await
            .map_err(ServerError::from)
    }

    async fn is_run_cancelled(
        &self,
        run_id: RunId,
    ) -> Result<bool, ServerError> {
        self.read_cancellation(run_id)
            .await
            .map_err(ServerError::from)
    }
}

impl From<NodeError> for ServerError {
    fn from(problem: NodeError) -> Self {
        Self {
            reason: problem.to_string(),
        }
    }
}
