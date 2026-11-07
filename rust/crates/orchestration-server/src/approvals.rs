use axum::Json;
use axum::extract::State;
use axum::http::StatusCode;
use chrono::{DateTime, Utc};
use orchestration_api::updates::ChangeTopic;
use orchestration_api::work::{CreateApprovalRequest, DecideApprovalRequest};
use orchestration_core::approval::{
    ApprovalAction, ApprovalDecision, ApprovalRequest, SignedDecision,
};
use orchestration_core::identifiers::{
    ApprovalId, DeviceId, RunId, generate_uuid,
};
use orchestration_core::run_lifecycle::{RunProblem, is_run_finished};
use orchestration_security::decisions::verify_decision;
use uuid::Uuid;

use crate::approval_text::{describe_decision, describe_request};
use crate::authentication::{AuthenticatedDevice, SignedRequest};
use crate::change::Change;
use crate::device_registration::signing_key_of;
use crate::error::ServerError;
use crate::extractors::{PathValue, parse_json_body};
use crate::runs::{find_run, holds_step};
use crate::server::SharedServer;
use crate::skill_improvements::save_approved_improvement;
use crate::stored_state::StoredState;

pub async fn list_approvals(
    State(server): State<SharedServer>,
    request: SignedRequest,
) -> Result<Json<Vec<ApprovalRequest>>, ServerError> {
    let caller = &request.caller;
    let approvals =
        server.read(|state| Ok(visible_approvals(state, caller)))?;
    Ok(Json(approvals))
}

pub async fn create_approval(
    State(server): State<SharedServer>,
    request: SignedRequest,
) -> Result<(StatusCode, Json<ApprovalRequest>), ServerError> {
    request.caller.require_runner()?;
    let create_request: CreateApprovalRequest =
        parse_json_body(&request.body)?;
    let runner_id = &request.caller.device_id;
    let approval = server.apply(runner_id, |state, now| {
        open_approval(state, runner_id, &create_request, now)
    })?;
    Ok((StatusCode::CREATED, Json(approval)))
}

pub async fn decide_approval(
    State(server): State<SharedServer>,
    PathValue(approval_uuid): PathValue<Uuid>,
    request: SignedRequest,
) -> Result<Json<ApprovalRequest>, ServerError> {
    request.caller.require_client()?;
    let decide_request: DecideApprovalRequest =
        parse_json_body(&request.body)?;
    let approval_id = ApprovalId(approval_uuid);
    let caller_id = &request.caller.device_id;
    let approval = server.apply(caller_id, |state, now| {
        let decided = record_decision(
            state,
            approval_id,
            caller_id,
            &decide_request.decision,
        )?;
        if decide_request.decision.decision == ApprovalDecision::Approved {
            save_approved_improvement(state, &decided.outcome, now);
        }
        Ok(decided)
    })?;
    Ok(Json(approval))
}

fn visible_approvals(
    state: &StoredState,
    caller: &AuthenticatedDevice,
) -> Vec<ApprovalRequest> {
    let mut approvals: Vec<ApprovalRequest> = Vec::new();
    for approval in state.approvals.values() {
        let is_asked_by_caller = approval.requested_by == caller.device_id;
        let is_open_to_person =
            caller.is_client() && !asks_about_finished_run(state, approval);
        if is_open_to_person || is_asked_by_caller {
            approvals.push(approval.clone());
        }
    }
    approvals.sort_by_key(|approval| (approval.requested_at, approval.id));
    approvals
}

pub fn require_step_holder(
    state: &StoredState,
    runner_id: &DeviceId,
    run_id: RunId,
) -> Result<(), ServerError> {
    let record = find_run(state, run_id)?;
    if !holds_step(&record.run, runner_id) {
        return Err(ServerError::Forbidden(
            "the runner holds no step of this run",
        ));
    }
    Ok(())
}

pub fn open_approval(
    state: &mut StoredState,
    runner_id: &DeviceId,
    request: &CreateApprovalRequest,
    now: DateTime<Utc>,
) -> Result<Change<ApprovalRequest>, ServerError> {
    if let Some(run_id) = request.run_id {
        require_step_holder(state, runner_id, run_id)?;
    }
    let approval = ApprovalRequest {
        id: ApprovalId(generate_uuid()),
        run_id: request.run_id,
        action: request.action.clone(),
        requested_by: runner_id.clone(),
        requested_at: now,
        decision: None,
    };
    state.approvals.insert(approval.id, approval.clone());
    let event_text = describe_request(&approval.action);
    Ok(Change::recorded(
        approval,
        ChangeTopic::Approvals,
        event_text,
    ))
}

fn asks_about_finished_run(
    state: &StoredState,
    approval: &ApprovalRequest,
) -> bool {
    let is_skill_proposal =
        matches!(approval.action, ApprovalAction::ImproveSkill { .. });
    if approval.decision.is_some() || is_skill_proposal {
        return false;
    }
    let Some(run_id) = approval.run_id else {
        return false;
    };
    let run_record = state.runs.get(&run_id);
    run_record.is_some_and(|record| is_run_finished(record.run.status))
}

fn record_decision(
    state: &mut StoredState,
    approval_id: ApprovalId,
    decider_id: &DeviceId,
    decision: &SignedDecision,
) -> Result<Change<ApprovalRequest>, ServerError> {
    if decision.decided_by != *decider_id {
        return Err(ServerError::Forbidden(
            "a device can only send its own decision",
        ));
    }
    let decider_key = signing_key_of(state, decider_id)
        .ok_or(ServerError::Forbidden("the deciding device is not trusted"))?;
    let stored_approval = state
        .approvals
        .get(&approval_id)
        .ok_or(ServerError::NotFound("the approval"))?;
    if asks_about_finished_run(state, stored_approval) {
        return Err(RunProblem::RunAlreadyFinished.into());
    }
    let approval = state
        .approvals
        .get_mut(&approval_id)
        .ok_or(ServerError::NotFound("the approval"))?;
    if approval.decision.is_some() {
        return Err(ServerError::Conflict(
            "the approval has already been decided".to_owned(),
        ));
    }
    verify_decision(approval, decision, &decider_key).map_err(|_| {
        ServerError::Forbidden("the decision signature does not verify")
    })?;

    approval.decision = Some(decision.clone());
    let decided = approval.clone();
    let event_text = describe_decision(decision.decision, &decided.action);
    Ok(Change::recorded(
        decided,
        ChangeTopic::Approvals,
        event_text,
    ))
}
