use orchestration_core::approval::{ApprovalAction, ApprovalRequest};
use orchestration_core::document_diff::{DiffLine, diff_lines};
use orchestration_core::library::Skill;
use serde::Serialize;

use crate::content_sealing::WorkspaceKeyring;
use crate::node_error::NodeError;

#[derive(Debug, Serialize)]
pub(super) struct SkillChangeView {
    skill_name: String,
    changes: Vec<DiffLine>,
}

pub(super) fn open_improvement_proposal(
    keyring: &WorkspaceKeyring,
    approval: &ApprovalRequest,
) -> Result<ApprovalRequest, NodeError> {
    let ApprovalAction::ImproveSkill {
        skill_id,
        summary,
        proposed_instructions,
    } = &approval.action
    else {
        return Ok(approval.clone());
    };

    let opened_action = ApprovalAction::ImproveSkill {
        skill_id: *skill_id,
        summary: summary.clone(),
        proposed_instructions: keyring.open_text(proposed_instructions)?,
    };
    Ok(ApprovalRequest {
        action: opened_action,
        ..approval.clone()
    })
}

pub(super) fn describe_skill_change(
    keyring: &WorkspaceKeyring,
    opened_action: &ApprovalAction,
    sealed_skills: &[Skill],
) -> Result<Option<SkillChangeView>, NodeError> {
    let ApprovalAction::ImproveSkill {
        skill_id,
        proposed_instructions,
        ..
    } = opened_action
    else {
        return Ok(None);
    };
    let improved_skill =
        sealed_skills.iter().find(|skill| skill.id == *skill_id);
    let Some(improved_skill) = improved_skill else {
        return Ok(None);
    };

    let current_instructions =
        keyring.open_text(&improved_skill.instructions)?;
    Ok(Some(SkillChangeView {
        skill_name: improved_skill.name.clone(),
        changes: diff_lines(&current_instructions, proposed_instructions),
    }))
}
