use axum::Json;
use axum::extract::State;
use axum::http::StatusCode;
use orchestration_api::catalog::SaveSkillRequest;
use orchestration_api::updates::ChangeTopic;
use orchestration_core::identifiers::SkillId;
use orchestration_core::library::Skill;
use orchestration_core::naming::validate_name;
use uuid::Uuid;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::error::ServerError;
use crate::extractors::{PathValue, parse_json_body};
use crate::server::SharedServer;
use crate::stored_state::StoredState;

pub async fn list_skills(
    State(server): State<SharedServer>,
    _request: SignedRequest,
) -> Result<Json<Vec<Skill>>, ServerError> {
    let skills =
        server.read(|state| Ok(state.skills.values().cloned().collect()))?;
    Ok(Json(skills))
}

pub async fn save_skill(
    State(server): State<SharedServer>,
    request: SignedRequest,
) -> Result<Json<Skill>, ServerError> {
    request.caller.require_client()?;
    let save_request: SaveSkillRequest = parse_json_body(&request.body)?;
    let skill = server.apply(&request.caller.device_id, |state, _now| {
        store_skill(state, &save_request.skill)
    })?;
    Ok(Json(skill))
}

pub async fn update_skill(
    State(server): State<SharedServer>,
    PathValue(skill_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Skill>, ServerError> {
    request.caller.require_client()?;
    let save_request: SaveSkillRequest = parse_json_body(&request.body)?;
    let skill_id = SkillId(skill_uuid);
    let skill = server.apply(&request.caller.device_id, |state, _now| {
        replace_skill(state, skill_id, &save_request.skill)
    })?;
    Ok(Json(skill))
}

pub async fn delete_skill(
    State(server): State<SharedServer>,
    PathValue(skill_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<StatusCode, ServerError> {
    request.caller.require_client()?;
    let skill_id = SkillId(skill_uuid);
    server.apply(&request.caller.device_id, |state, _now| {
        remove_skill(state, skill_id)
    })?;
    Ok(StatusCode::NO_CONTENT)
}

fn store_skill(
    state: &mut StoredState,
    skill: &Skill,
) -> Result<Change<Skill>, ServerError> {
    validate_name(&skill.name)?;
    state.skills.insert(skill.id, skill.clone());
    let event_text = format!("Saved skill {}", skill.name);
    Ok(Change::recorded(
        skill.clone(),
        ChangeTopic::Skills,
        event_text,
    ))
}

fn replace_skill(
    state: &mut StoredState,
    skill_id: SkillId,
    skill: &Skill,
) -> Result<Change<Skill>, ServerError> {
    let existing = state
        .skills
        .get(&skill_id)
        .ok_or(ServerError::NotFound("the skill"))?;
    if skill.id != skill_id {
        return Err(ServerError::Invalid(
            "the skill id does not match the address".to_owned(),
        ));
    }
    validate_name(&skill.name)?;

    let replaced = Skill {
        source: existing.source,
        ..skill.clone()
    };
    state.skills.insert(skill_id, replaced.clone());
    let event_text = format!("Changed skill {}", replaced.name);
    Ok(Change::recorded(replaced, ChangeTopic::Skills, event_text))
}

fn remove_skill(
    state: &mut StoredState,
    skill_id: SkillId,
) -> Result<Change<()>, ServerError> {
    let removed = state
        .skills
        .remove(&skill_id)
        .ok_or(ServerError::NotFound("the skill"))?;
    let event_text = format!("Deleted skill {}", removed.name);
    Ok(Change::recorded((), ChangeTopic::Skills, event_text))
}
