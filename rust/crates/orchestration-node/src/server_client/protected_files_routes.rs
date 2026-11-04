use orchestration_api::catalog::SetProtectedFilesRequest;
use orchestration_api::routes::WORKSPACE_PROTECTED_FILES;
use orchestration_core::identifiers::WorkspaceId;
use orchestration_core::workspace::Workspace;
use reqwest::Method;

use super::route_paths::fill_route;
use super::signed_server_client::SignedServerClient;
use crate::node_error::NodeError;

const WORKSPACE_PLACEHOLDER: &str = "workspace_id";

impl SignedServerClient<'_> {
    pub async fn set_protected_files(
        &self,
        workspace_id: WorkspaceId,
        request: &SetProtectedFilesRequest,
    ) -> Result<Workspace, NodeError> {
        let workspace_text = workspace_id.0.to_string();
        let path = fill_route(
            WORKSPACE_PROTECTED_FILES,
            &[(WORKSPACE_PLACEHOLDER, &workspace_text)],
        )?;
        self.exchange(Method::PUT, &path, request).await
    }
}
