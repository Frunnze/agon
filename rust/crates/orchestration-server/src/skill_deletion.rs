use std::collections::BTreeSet;

use axum::extract::State;
use axum::http::StatusCode;
use orchestration_api::updates::ChangeTopic;
use orchestration_core::identifiers::SkillId;
use uuid::Uuid;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::error::ServerError;
use crate::events::append_notification;
use crate::extractors::PathValue;
use crate::server::SharedServer;
use crate::stored_state::StoredState;

pub async fn delete_skill(
    State(server): State<SharedServer>,
    PathValue(skill_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<StatusCode, ServerError> {
    request.caller.require_client()?;
    let skill_id = SkillId(skill_uuid);
    server.apply(&request.caller.device_id, |state, _now| {
        drop_skill(state, skill_id)
    })?;
    Ok(StatusCode::NO_CONTENT)
}

pub fn forget_skills_in_tasks(
    state: &mut StoredState,
    skill_ids: &BTreeSet<SkillId>,
) {
    for task in state.tasks.values_mut() {
        task.skills.retain(|skill_id| !skill_ids.contains(skill_id));
    }
}

fn drop_skill(
    state: &mut StoredState,
    skill_id: SkillId,
) -> Result<Change<()>, ServerError> {
    let removed = state
        .skills
        .remove(&skill_id)
        .ok_or(ServerError::NotFound("the skill"))?;
    forget_skills_in_tasks(state, &BTreeSet::from([skill_id]));
    append_notification(state, ChangeTopic::Tasks);
    let event_text = format!("Deleted skill {}", removed.name);
    Ok(Change::recorded((), ChangeTopic::Skills, event_text))
}
