use std::collections::BTreeMap;

use chrono::Utc;
use orchestration_api::work::{CreateApprovalRequest, DecideApprovalRequest};
use orchestration_core::approval::{
    ApprovalAction, ApprovalDecision, ApprovalRequest,
};
use orchestration_core::identifiers::{ApprovalId, RunId, WorkflowId};
use orchestration_core::library::Skill;
use orchestration_security::decisions::sign_decision;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::skill_change_view::{
    SkillChangeView, describe_skill_change, open_improvement_proposal,
};
use crate::command_reply::encode_reply;
use crate::content_sealing::WorkspaceKeyring;
use crate::node::Node;
use crate::node_error::NodeError;
use crate::views::describe_approval_action;

pub(super) const APPROVAL_COMMAND_NAMES: [&str; 3] =
    ["list_approvals", "create_approval", "decide_approval"];

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum ApprovalCommand {
    ListApprovals {},
    CreateApproval {
        run_id: Option<RunId>,
        action: ApprovalAction,
    },
    DecideApproval {
        approval_id: ApprovalId,
        decision: ApprovalDecision,
    },
}

#[derive(Debug, Serialize)]
struct ApprovalView {
    approval: ApprovalRequest,
    description: String,
    is_waiting: bool,
    skill_change: Option<SkillChangeView>,
}

#[derive(Debug, Serialize)]
struct ApprovalsView {
    waiting_count: usize,
    approvals: Vec<ApprovalView>,
}

pub(super) async fn handle_approval_command(
    node: &Node,
    command: ApprovalCommand,
) -> Result<Value, NodeError> {
    let session = node.open_session()?;
    let client = session.client();
    match command {
        ApprovalCommand::ListApprovals {} => {
            let approvals = client.list_approvals().await?;
            let mut workflow_names = BTreeMap::new();
            for listing in client.list_workflows().await? {
                let workflow = listing.workflow;
                workflow_names.insert(workflow.id, workflow.name);
            }
            let sealed_skills = client.list_skills().await?;
            let approvals_view = build_approvals_view(
                &session.keyring,
                approvals,
                &workflow_names,
                &sealed_skills,
            )?;
            encode_reply(&approvals_view)
        }
        ApprovalCommand::CreateApproval { run_id, action } => {
            let request = CreateApprovalRequest { run_id, action };
            encode_reply(&client.create_approval(&request).await?)
        }
        ApprovalCommand::DecideApproval {
            approval_id,
            decision,
        } => {
            let approvals = client.list_approvals().await?;
            let approval = approvals
                .iter()
                .find(|approval| approval.id == approval_id)
                .ok_or_else(|| NodeError::NotFound {
                    kind: "approval",
                    identifier: approval_id.0.to_string(),
                })?;
            let signed_decision = sign_decision(
                &session.identity,
                approval,
                decision,
                Utc::now(),
            )?;
            let request = DecideApprovalRequest {
                decision: signed_decision,
            };
            client.decide_approval(approval_id, &request).await?;
            Ok(Value::Null)
        }
    }
}

fn build_approvals_view(
    keyring: &WorkspaceKeyring,
    approvals: Vec<ApprovalRequest>,
    workflow_names: &BTreeMap<WorkflowId, String>,
    sealed_skills: &[Skill],
) -> Result<ApprovalsView, NodeError> {
    let mut approval_views = Vec::new();
    for approval in approvals {
        let description =
            describe_approval_action(&approval.action, workflow_names);
        let opened_approval = open_improvement_proposal(keyring, &approval)?;
        let skill_change = describe_skill_change(
            keyring,
            &opened_approval.action,
            sealed_skills,
        )?;
        approval_views.push(ApprovalView {
            is_waiting: approval.decision.is_none(),
            approval: opened_approval,
            description,
            skill_change,
        });
    }
    let waiting_count = approval_views
        .iter()
        .filter(|approval_view| approval_view.is_waiting)
        .count();
    Ok(ApprovalsView {
        waiting_count,
        approvals: approval_views,
    })
}
