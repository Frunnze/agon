use std::sync::Arc;

use axum::Router;
use axum::http::StatusCode;
use axum::middleware::from_fn_with_state;
use axum::routing::{delete, get, post, put};
use orchestration_api::routes::{
    ACCOUNTS, APPROVAL_DECISION, APPROVALS, AUDIT, DEVICE_PEER_ADDRESS,
    DEVICE_REVOKE, DEVICES, EVENTS, HEALTH, PAIRING_APPROVE,
    PAIRING_APPROVER_NONCE, PAIRING_CANCEL, PAIRING_COMMITMENT, PAIRING_JOIN,
    PAIRING_JOIN_STATUS, PAIRING_JOINER_NONCE, PAIRING_REJECT,
    PAIRING_SESSION, PAIRING_SESSIONS, PERSON_STEPS, PROJECT,
    PROJECT_REPOSITORIES, PROJECTS, RULE, RULE_ENABLED, RULES, RUN,
    RUN_CANCEL, RUN_EVENTS, RUN_MESSAGES, RUN_RETRY, RUN_STEP_ANSWER,
    RUNNER_ACCEPTING, RUNNER_CLAIM, RUNNER_HEARTBEAT, RUNNERS, RUNS,
    SERVER_GROUP, SERVER_GROUP_MEMBER, SERVER_GROUP_MEMBERS,
    SERVER_GROUP_REPLICA, SKILL, SKILLS, TASK, TASK_RUNS, TASKS, WORKFLOW,
    WORKFLOW_DISCARD, WORKFLOW_SIGNATURE, WORKFLOWS, WORKSPACE,
    WORKSPACE_DEVICE, WORKSPACE_DEVICES, WORKSPACES,
};

use crate::backup_guard::refuse_on_backup;
use crate::error::ServerError;
use crate::server::SharedServer;
use crate::{
    accounts, approvals, audit_log, claims, devices, events, pairing_endings,
    pairing_exchange, pairing_joins, pairing_sessions, peer_addresses,
    person_steps, project_deletion, projects, rules, run_events, runners,
    runs, server_group_routes, skill_deletion, skills, task_deletion, tasks,
    workflow_deletion, workflows, workspace_deletion, workspaces,
};

pub fn build_router(server: SharedServer) -> Router {
    Router::new()
        .route(HEALTH, get(report_health))
        .merge(account_routes())
        .merge(catalog_routes())
        .merge(work_routes())
        .merge(server_group_routes())
        .fallback(report_unknown_route)
        .layer(from_fn_with_state(Arc::clone(&server), refuse_on_backup))
        .with_state(server)
}

fn server_group_routes() -> Router<SharedServer> {
    Router::new()
        .route(SERVER_GROUP, get(server_group_routes::show_server_group))
        .route(
            SERVER_GROUP_MEMBERS,
            put(server_group_routes::register_server_member),
        )
        .route(
            SERVER_GROUP_MEMBER,
            delete(server_group_routes::remove_server_member),
        )
        .route(
            SERVER_GROUP_REPLICA,
            get(server_group_routes::fetch_replica),
        )
}

fn account_routes() -> Router<SharedServer> {
    Router::new()
        .route(
            ACCOUNTS,
            post(accounts::create_account).get(accounts::show_account),
        )
        .route(PAIRING_SESSIONS, post(pairing_sessions::start_pairing))
        .route(PAIRING_SESSION, get(pairing_sessions::show_pairing_request))
        .route(PAIRING_COMMITMENT, post(pairing_exchange::commit_pairing))
        .route(
            PAIRING_APPROVER_NONCE,
            post(pairing_exchange::reveal_approver_nonce),
        )
        .route(PAIRING_APPROVE, post(pairing_sessions::approve_pairing))
        .route(PAIRING_REJECT, post(pairing_endings::reject_pairing))
        .route(PAIRING_CANCEL, post(pairing_endings::cancel_pairing))
        .route(PAIRING_JOIN, post(pairing_joins::join_pairing))
        .route(PAIRING_JOIN_STATUS, get(pairing_joins::show_join_status))
        .route(
            PAIRING_JOINER_NONCE,
            post(pairing_exchange::receive_joiner_nonce),
        )
        .route(DEVICES, get(devices::list_devices))
        .route(DEVICE_REVOKE, post(devices::revoke_device))
        .route(
            DEVICE_PEER_ADDRESS,
            put(peer_addresses::publish_peer_address),
        )
        .route(
            WORKSPACES,
            get(workspaces::list_workspaces)
                .post(workspaces::create_workspace),
        )
        .route(WORKSPACE, delete(workspace_deletion::delete_workspace))
        .route(WORKSPACE_DEVICES, post(workspaces::add_workspace_device))
        .route(
            WORKSPACE_DEVICE,
            delete(workspaces::remove_workspace_device),
        )
        .route(AUDIT, get(audit_log::show_audit_log))
        .route(EVENTS, get(events::poll_events))
}

fn catalog_routes() -> Router<SharedServer> {
    Router::new()
        .route(
            PROJECTS,
            get(projects::list_projects).post(projects::save_project),
        )
        .route(PROJECT, delete(project_deletion::delete_project))
        .route(
            PROJECT_REPOSITORIES,
            post(projects::add_repository).delete(projects::remove_repository),
        )
        .route(
            WORKFLOWS,
            get(workflows::list_workflows).post(workflows::create_workflow),
        )
        .route(
            WORKFLOW,
            put(workflows::update_workflow)
                .delete(workflow_deletion::delete_workflow),
        )
        .route(WORKFLOW_SIGNATURE, post(workflows::sign_workflow))
        .route(WORKFLOW_DISCARD, post(workflows::discard_workflow_change))
        .route(SKILLS, get(skills::list_skills).post(skills::save_skill))
        .route(
            SKILL,
            put(skills::update_skill).delete(skill_deletion::delete_skill),
        )
        .route(RULES, get(rules::list_rules).post(rules::save_rule))
        .route(RULE, put(rules::update_rule).delete(rules::delete_rule))
        .route(RULE_ENABLED, put(rules::set_rule_enabled))
}

fn work_routes() -> Router<SharedServer> {
    Router::new()
        .route(TASKS, get(tasks::list_tasks).post(tasks::save_task))
        .route(
            TASK,
            put(tasks::update_task).delete(task_deletion::delete_task),
        )
        .route(
            TASK_RUNS,
            get(runs::list_task_runs).post(runs::start_task_run),
        )
        .route(RUNS, get(runs::list_runs))
        .route(RUN, get(runs::show_run))
        .route(RUN_CANCEL, post(runs::cancel_run))
        .route(RUN_RETRY, post(runs::retry_run))
        .route(RUN_MESSAGES, post(runs::send_chat_message))
        .route(RUN_EVENTS, post(run_events::post_run_events))
        .route(RUN_STEP_ANSWER, post(person_steps::answer_person_step))
        .route(PERSON_STEPS, get(person_steps::list_person_steps))
        .route(RUNNERS, get(runners::list_runners))
        .route(RUNNER_HEARTBEAT, post(runners::receive_heartbeat))
        .route(RUNNER_CLAIM, post(claims::claim_next_run))
        .route(RUNNER_ACCEPTING, put(runners::set_accepting_runs))
        .route(
            APPROVALS,
            get(approvals::list_approvals).post(approvals::create_approval),
        )
        .route(APPROVAL_DECISION, post(approvals::decide_approval))
}

async fn report_health() -> StatusCode {
    StatusCode::OK
}

async fn report_unknown_route() -> ServerError {
    ServerError::NotFound("the route")
}
