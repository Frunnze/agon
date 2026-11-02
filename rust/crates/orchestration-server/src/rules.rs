use axum::Json;
use axum::extract::State;
use axum::http::StatusCode;
use orchestration_api::catalog::{SaveRuleRequest, SetRuleEnabledRequest};
use orchestration_api::updates::ChangeTopic;
use orchestration_core::identifiers::RuleId;
use orchestration_core::library::Rule;
use uuid::Uuid;

use crate::authentication::SignedRequest;
use crate::change::Change;
use crate::error::ServerError;
use crate::extractors::{PathValue, parse_json_body};
use crate::server::SharedServer;
use crate::stored_state::StoredState;

pub async fn list_rules(
    State(server): State<SharedServer>,
    _request: SignedRequest,
) -> Result<Json<Vec<Rule>>, ServerError> {
    let rules =
        server.read(|state| Ok(state.rules.values().cloned().collect()))?;
    Ok(Json(rules))
}

pub async fn save_rule(
    State(server): State<SharedServer>,
    request: SignedRequest,
) -> Result<Json<Rule>, ServerError> {
    request.caller.require_client()?;
    let save_request: SaveRuleRequest = parse_json_body(&request.body)?;
    let rule = server.apply(&request.caller.device_id, |state, _now| {
        Ok(store_rule(state, &save_request.rule))
    })?;
    Ok(Json(rule))
}

pub async fn set_rule_enabled(
    State(server): State<SharedServer>,
    PathValue(rule_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Rule>, ServerError> {
    request.caller.require_client()?;
    let toggle: SetRuleEnabledRequest = parse_json_body(&request.body)?;
    let rule_id = RuleId(rule_uuid);
    let rule = server.apply(&request.caller.device_id, |state, _now| {
        switch_rule(state, rule_id, toggle.enabled)
    })?;
    Ok(Json(rule))
}

pub async fn update_rule(
    State(server): State<SharedServer>,
    PathValue(rule_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<Rule>, ServerError> {
    request.caller.require_client()?;
    let save_request: SaveRuleRequest = parse_json_body(&request.body)?;
    let rule_id = RuleId(rule_uuid);
    let rule = server.apply(&request.caller.device_id, |state, _now| {
        replace_rule(state, rule_id, &save_request.rule)
    })?;
    Ok(Json(rule))
}

pub async fn delete_rule(
    State(server): State<SharedServer>,
    PathValue(rule_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<StatusCode, ServerError> {
    request.caller.require_client()?;
    let rule_id = RuleId(rule_uuid);
    server.apply(&request.caller.device_id, |state, _now| {
        remove_rule(state, rule_id)
    })?;
    Ok(StatusCode::NO_CONTENT)
}

fn store_rule(state: &mut StoredState, rule: &Rule) -> Change<Rule> {
    let is_new = !state.rules.contains_key(&rule.id);
    state.rules.insert(rule.id, rule.clone());
    let verb = if is_new { "Added" } else { "Changed" };
    let event_text = format!("{verb} rule {}", rule.title);
    Change::recorded(rule.clone(), ChangeTopic::Rules, event_text)
}

fn switch_rule(
    state: &mut StoredState,
    rule_id: RuleId,
    enabled: bool,
) -> Result<Change<Rule>, ServerError> {
    let rule = state
        .rules
        .get_mut(&rule_id)
        .ok_or(ServerError::NotFound("the rule"))?;
    rule.enabled = enabled;
    let switched = rule.clone();
    let verb = if enabled { "Turned on" } else { "Turned off" };
    let event_text = format!("{verb} rule {}", switched.title);
    Ok(Change::recorded(switched, ChangeTopic::Rules, event_text))
}

fn replace_rule(
    state: &mut StoredState,
    rule_id: RuleId,
    rule: &Rule,
) -> Result<Change<Rule>, ServerError> {
    let existing = state
        .rules
        .get(&rule_id)
        .ok_or(ServerError::NotFound("the rule"))?;
    if rule.id != rule_id {
        return Err(ServerError::Invalid(
            "the rule id does not match the address".to_owned(),
        ));
    }

    let replaced = Rule {
        enabled: existing.enabled,
        added_at: existing.added_at,
        ..rule.clone()
    };
    state.rules.insert(rule_id, replaced.clone());
    let event_text = format!("Changed rule {}", replaced.title);
    Ok(Change::recorded(replaced, ChangeTopic::Rules, event_text))
}

fn remove_rule(
    state: &mut StoredState,
    rule_id: RuleId,
) -> Result<Change<()>, ServerError> {
    let removed = state
        .rules
        .remove(&rule_id)
        .ok_or(ServerError::NotFound("the rule"))?;
    let event_text = format!("Deleted rule {}", removed.title);
    Ok(Change::recorded((), ChangeTopic::Rules, event_text))
}
