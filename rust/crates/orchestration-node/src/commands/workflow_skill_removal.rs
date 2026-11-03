use orchestration_api::catalog::SaveWorkflowRequest;
use orchestration_core::identifiers::SkillId;
use orchestration_core::workflow::{SignatureState, Workflow, WorkflowAgent};

use super::workflow_commands::sign_workflow;
use super::workflow_view::read_signature_state;
use crate::node::DeviceSession;
use crate::node_error::NodeError;
use crate::server_client::SignedServerClient;

pub(super) async fn remove_skill_from_workflows(
    session: &DeviceSession,
    client: &SignedServerClient<'_>,
    skill_id: SkillId,
) -> Result<(), NodeError> {
    let devices = client.list_devices().await?;
    for listing in client.list_workflows().await? {
        let stored_workflow = &listing.workflow;
        if !uses_skill(stored_workflow, skill_id) {
            continue;
        }

        let state = read_signature_state(stored_workflow, &devices);
        let was_signed = state == SignatureState::Signed;
        let request = SaveWorkflowRequest {
            workflow: without_skill(stored_workflow, skill_id),
        };
        client.update_workflow(stored_workflow.id, &request).await?;

        if was_signed {
            sign_workflow(session, client, stored_workflow.id).await?;
        }
    }
    Ok(())
}

fn uses_skill(workflow: &Workflow, skill_id: SkillId) -> bool {
    workflow
        .agents
        .iter()
        .any(|agent| agent.skills.contains(&skill_id))
}

fn without_skill(workflow: &Workflow, skill_id: SkillId) -> Workflow {
    let mut agents = Vec::new();
    for agent in &workflow.agents {
        let mut skills = agent.skills.clone();
        skills.retain(|kept_skill| *kept_skill != skill_id);
        agents.push(WorkflowAgent {
            skills,
            ..agent.clone()
        });
    }
    Workflow {
        agents,
        ..workflow.clone()
    }
}
