use orchestration_api::routes::{PROJECT, TASK, WORKFLOW, WORKSPACE};
use orchestration_core::identifiers::{
    ProjectId, TaskId, WorkflowId, WorkspaceId,
};
use reqwest::Method;

use super::route_paths::fill_route;
use super::signed_server_client::SignedServerClient;
use crate::node_error::NodeError;

const PROJECT_PLACEHOLDER: &str = "project_id";
const WORKFLOW_PLACEHOLDER: &str = "workflow_id";
const TASK_PLACEHOLDER: &str = "task_id";
const WORKSPACE_PLACEHOLDER: &str = "workspace_id";

impl SignedServerClient<'_> {
    pub async fn delete_project(
        &self,
        project_id: ProjectId,
    ) -> Result<(), NodeError> {
        let project_text = project_id.0.to_string();
        self.delete_record(PROJECT, PROJECT_PLACEHOLDER, &project_text)
            .await
    }

    pub async fn delete_workflow(
        &self,
        workflow_id: WorkflowId,
    ) -> Result<(), NodeError> {
        let workflow_text = workflow_id.0.to_string();
        self.delete_record(WORKFLOW, WORKFLOW_PLACEHOLDER, &workflow_text)
            .await
    }

    pub async fn delete_task(&self, task_id: TaskId) -> Result<(), NodeError> {
        let task_text = task_id.0.to_string();
        self.delete_record(TASK, TASK_PLACEHOLDER, &task_text).await
    }

    pub async fn delete_workspace(
        &self,
        workspace_id: WorkspaceId,
    ) -> Result<(), NodeError> {
        let workspace_text = workspace_id.0.to_string();
        self.delete_record(WORKSPACE, WORKSPACE_PLACEHOLDER, &workspace_text)
            .await
    }

    async fn delete_record(
        &self,
        template: &str,
        placeholder: &str,
        identifier: &str,
    ) -> Result<(), NodeError> {
        let path = fill_route(template, &[(placeholder, identifier)])?;
        self.submit_without_body(Method::DELETE, &path).await?;
        Ok(())
    }
}
