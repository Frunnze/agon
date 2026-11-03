use axum::Json;
use axum::extract::State;
use axum::http::StatusCode;
use chrono::{DateTime, Utc};
use orchestration_api::catalog::ImproveSkillRequest;
use orchestration_api::updates::ChangeTopic;
use orchestration_api::work::CreateApprovalRequest;
use orchestration_core::approval::{ApprovalAction, ApprovalRequest};
use orchestration_core::identifiers::{DeviceId, SkillId};
use orchestration_core::library::{
    Skill, SkillChangeOrigin, SkillImprovement,
};
use orchestration_core::skill_history::{
    record_skill_change, undo_latest_agent_change,
};
use uuid::Uuid;

use crate::approvals::{open_approval, require_step_holder};
use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::error::ServerError;
use crate::events::append_notification;
use crate::extractors::{PathValue, parse_json_body};
use crate::server::SharedServer;
use crate::stored_state::StoredState;

const UNKNOWN_SKILL: &str = "the skill";
const NEVER_IMPROVED: &str = "agents may not improve this skill";

pub async fn improve_skill(
    State(server): State<SharedServer>,
    PathValue(skill_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<StatusCode, ServerError> {
    request.caller.require_runner()?;
    let improvement: ImproveSkillRequest = parse_json_body(&request.body)?;
    let skill_id = SkillId(skill_uuid);
    let runner_id = &request.caller.device_id;
    server.apply(runner_id, |state, now| {
        take_improvement(state, runner_id, skill_id, &improvement, now)
    })?;
    Ok(StatusCode::NO_CONTENT)
}

pub async fn undo_skill_change(
    State(server): State<SharedServer>,
    PathValue(skill_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Skill>, ServerError> {
    request.caller.require_client()?;
    let skill_id = SkillId(skill_uuid);
    let skill = server.apply(&request.caller.device_id, |state, _now| {
        restore_previous_version(state, skill_id)
    })?;
    Ok(Json(skill))
}

pub fn save_approved_improvement(
    state: &mut StoredState,
    approval: &ApprovalRequest,
    now: DateTime<Utc>,
) {
    let ApprovalAction::ImproveSkill {
        skill_id,
        proposed_instructions,
        ..
    } = &approval.action
    else {
        return;
    };
    let (Some(run_id), Some(skill)) =
        (approval.run_id, state.skills.get(skill_id).cloned())
    else {
        return;
    };

    let origin = SkillChangeOrigin::ApprovedAgentRun { run_id };
    save_improvement(state, &skill, proposed_instructions, origin, now);
    append_notification(state, ChangeTopic::Skills);
}

fn take_improvement(
    state: &mut StoredState,
    runner_id: &DeviceId,
    skill_id: SkillId,
    improvement: &ImproveSkillRequest,
    now: DateTime<Utc>,
) -> Result<Change<()>, ServerError> {
    let skill = state
        .skills
        .get(&skill_id)
        .cloned()
        .ok_or(ServerError::NotFound(UNKNOWN_SKILL))?;
    require_step_holder(state, runner_id, improvement.run_id)?;

    match skill.improvement {
        SkillImprovement::Never => Err(ServerError::Forbidden(NEVER_IMPROVED)),
        SkillImprovement::AskMe => {
            ask_to_improve(state, runner_id, skill_id, improvement, now)
        }
        SkillImprovement::Auto => {
            let origin = SkillChangeOrigin::AutomaticAgentRun {
                run_id: improvement.run_id,
            };
            let instructions = &improvement.instructions;
            save_improvement(state, &skill, instructions, origin, now);
            let event_text = format!("An agent improved skill {}", skill.name);
            Ok(Change::recorded((), ChangeTopic::Skills, event_text))
        }
    }
}

fn ask_to_improve(
    state: &mut StoredState,
    runner_id: &DeviceId,
    skill_id: SkillId,
    improvement: &ImproveSkillRequest,
    now: DateTime<Utc>,
) -> Result<Change<()>, ServerError> {
    let approval_request = CreateApprovalRequest {
        run_id: Some(improvement.run_id),
        action: ApprovalAction::ImproveSkill {
            skill_id,
            summary: improvement.summary.clone(),
            proposed_instructions: improvement.instructions.clone(),
        },
    };
    let opened = open_approval(state, runner_id, &approval_request, now)?;
    Ok(Change {
        outcome: (),
        effect: opened.effect,
    })
}

fn save_improvement(
    state: &mut StoredState,
    skill: &Skill,
    instructions: &str,
    origin: SkillChangeOrigin,
    now: DateTime<Utc>,
) {
    let improved = record_skill_change(skill, instructions, origin, now);
    state.skills.insert(skill.id, improved);
}

fn restore_previous_version(
    state: &mut StoredState,
    skill_id: SkillId,
) -> Result<Change<Skill>, ServerError> {
    let skill = state
        .skills
        .get(&skill_id)
        .ok_or(ServerError::NotFound(UNKNOWN_SKILL))?;
    let restored = undo_latest_agent_change(skill)
        .map_err(|problem| ServerError::Conflict(problem.to_string()))?;

    state.skills.insert(skill_id, restored.clone());
    let event_text =
        format!("Undid the agent change to skill {}", restored.name);
    Ok(Change::recorded(restored, ChangeTopic::Skills, event_text))
}
