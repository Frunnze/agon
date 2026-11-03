use orchestration_api::routes::{PERSON_STEPS, RUN_STEP_ANSWER};
use orchestration_api::work::{AnswerPersonStepRequest, OpenPersonStep};
use orchestration_core::identifiers::RunId;
use orchestration_core::run::Run;
use reqwest::Method;

use super::route_paths::encode_path_segment;
use super::signed_server_client::SignedServerClient;
use super::work_routes::fill_run_route;
use crate::node_error::NodeError;

const STEP_NAME_MARKER: &str = "{step_name}";

impl SignedServerClient<'_> {
    pub async fn list_person_steps(
        &self,
    ) -> Result<Vec<OpenPersonStep>, NodeError> {
        self.fetch(PERSON_STEPS).await
    }

    pub async fn answer_person_step(
        &self,
        run_id: RunId,
        step_name: &str,
        request: &AnswerPersonStepRequest,
    ) -> Result<Run, NodeError> {
        let encoded_step_name = encode_path_segment(step_name);
        let template =
            RUN_STEP_ANSWER.replace(STEP_NAME_MARKER, &encoded_step_name);
        let path = fill_run_route(&template, run_id)?;
        self.exchange(Method::POST, &path, request).await
    }
}
