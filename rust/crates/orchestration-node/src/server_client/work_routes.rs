use orchestration_api::routes::{
    APPROVAL_DECISION, APPROVALS, RUN, RUN_CANCEL, RUN_MESSAGES, RUN_RETRY,
    RUNS, TASK, TASK_RUNS, TASKS,
};
use orchestration_api::work::{
    CreateApprovalRequest, DecideApprovalRequest, SaveTaskRequest,
    SendChatMessageRequest, UpdateTaskRequest,
};
use orchestration_core::approval::ApprovalRequest;
use orchestration_core::identifiers::{ApprovalId, RunId, TaskId};
use orchestration_core::run::Run;
use orchestration_core::task::Task;
use reqwest::Method;

use super::decode_answer;
use super::route_paths::fill_route;
use super::signed_server_client::SignedServerClient;
use crate::node_error::NodeError;

const TASK_PLACEHOLDER: &str = "task_id";
const RUN_PLACEHOLDER: &str = "run_id";
const APPROVAL_PLACEHOLDER: &str = "approval_id";

impl SignedServerClient<'_> {
    pub async fn list_tasks(&self) -> Result<Vec<Task>, NodeError> {
        self.fetch(TASKS).await
    }

    pub async fn save_task(
        &self,
        request: &SaveTaskRequest,
    ) -> Result<(), NodeError> {
        self.submit(Method::POST, TASKS, request).await
    }

    pub async fn update_task(
        &self,
        task_id: TaskId,
        request: &UpdateTaskRequest,
    ) -> Result<Task, NodeError> {
        let path = fill_task_route(TASK, task_id)?;
        self.exchange(Method::PUT, &path, request).await
    }

    pub async fn start_task(&self, task_id: TaskId) -> Result<Run, NodeError> {
        let path = fill_task_route(TASK_RUNS, task_id)?;
        let answer = self.submit_without_body(Method::POST, &path).await?;
        decode_answer(&answer)
    }

    pub async fn list_task_runs(
        &self,
        task_id: TaskId,
    ) -> Result<Vec<Run>, NodeError> {
        let path = fill_task_route(TASK_RUNS, task_id)?;
        self.fetch(&path).await
    }

    pub async fn list_runs(&self) -> Result<Vec<Run>, NodeError> {
        self.fetch(RUNS).await
    }

    pub async fn read_run(&self, run_id: RunId) -> Result<Run, NodeError> {
        let path = fill_run_route(RUN, run_id)?;
        self.fetch(&path).await
    }

    pub async fn cancel_run(&self, run_id: RunId) -> Result<(), NodeError> {
        let path = fill_run_route(RUN_CANCEL, run_id)?;
        self.submit_without_body(Method::POST, &path).await?;
        Ok(())
    }

    pub async fn retry_run(&self, run_id: RunId) -> Result<(), NodeError> {
        let path = fill_run_route(RUN_RETRY, run_id)?;
        self.submit_without_body(Method::POST, &path).await?;
        Ok(())
    }

    pub async fn send_chat_message(
        &self,
        run_id: RunId,
        request: &SendChatMessageRequest,
    ) -> Result<(), NodeError> {
        let path = fill_run_route(RUN_MESSAGES, run_id)?;
        self.submit(Method::POST, &path, request).await
    }

    pub async fn list_approvals(
        &self,
    ) -> Result<Vec<ApprovalRequest>, NodeError> {
        self.fetch(APPROVALS).await
    }

    pub async fn create_approval(
        &self,
        request: &CreateApprovalRequest,
    ) -> Result<ApprovalRequest, NodeError> {
        self.exchange(Method::POST, APPROVALS, request).await
    }

    pub async fn decide_approval(
        &self,
        approval_id: ApprovalId,
        request: &DecideApprovalRequest,
    ) -> Result<(), NodeError> {
        let approval_text = approval_id.0.to_string();
        let path = fill_route(
            APPROVAL_DECISION,
            &[(APPROVAL_PLACEHOLDER, &approval_text)],
        )?;
        self.submit(Method::POST, &path, request).await
    }
}

pub(super) fn fill_run_route(
    template: &str,
    run_id: RunId,
) -> Result<String, NodeError> {
    let run_text = run_id.0.to_string();
    fill_route(template, &[(RUN_PLACEHOLDER, &run_text)])
}

fn fill_task_route(
    template: &str,
    task_id: TaskId,
) -> Result<String, NodeError> {
    let task_text = task_id.0.to_string();
    fill_route(template, &[(TASK_PLACEHOLDER, &task_text)])
}
