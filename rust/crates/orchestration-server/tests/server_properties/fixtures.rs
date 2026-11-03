use axum::http::StatusCode;
use orchestration_api::accounts::{
    AccountView, CreateAccountRequest, DeviceRegistration,
};
use orchestration_api::catalog::SaveProjectRequest;
use orchestration_api::routes::{ACCOUNTS, PROJECTS, RUNNER_HEARTBEAT, TASKS};
use orchestration_api::work::{
    HeartbeatRequest, SaveTaskRequest, TaskSaved, TaskStart,
};
use orchestration_core::agent_place::AgentPlace;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::{
    Device, DeviceRole, HardwareKeyKind, Runner, RunnerLink, RunnerTarget,
};
use orchestration_core::identifiers::{ProjectId, TaskId, WorkspaceId};
use orchestration_core::task::{
    Schedule, Task, TaskDoer, TaskPlace, TaskStatus,
};
use orchestration_core::workflow::AgentKind;
use orchestration_core::workspace::{AgentAccess, Project, Repository};
use orchestration_security::identity::{
    DeviceIdentity, IDENTITY_SECRET_LENGTH,
};
use uuid::Uuid;

use crate::pairing_fixtures::{approve_session, join_session, start_pairing};
use crate::test_client::TestServer;

pub const OWNER_SEED: u8 = 1;
pub const WORKSPACE_NAME: &str = "acme";
pub const PROJECT_NAME: &str = "acme-app";
pub const SEALED_KEY_BYTES: [u8; 4] = [9, 8, 7, 6];
pub const SEALED_DETAILS: &str = "sealed-v1:c2hpcCByZWxlYXNl";

#[derive(Debug)]
pub struct Account {
    pub owner: DeviceIdentity,
    pub workspace_id: WorkspaceId,
}

pub fn identity_from_seed(seed: u8) -> DeviceIdentity {
    let secret_bytes = [seed; IDENTITY_SECRET_LENGTH];
    DeviceIdentity::from_secret_bytes(&secret_bytes)
        .expect("any seed makes an identity")
}

pub fn registration_for(
    identity: &DeviceIdentity,
    name: &str,
    role: DeviceRole,
) -> DeviceRegistration {
    let public_identity = identity.public_identity();
    DeviceRegistration {
        name: name.to_owned(),
        role,
        key_kind: HardwareKeyKind::Software,
        signing_public_key: public_identity.signing_public_key,
        sealing_public_key: public_identity.sealing_public_key,
    }
}

pub fn account_request_for(
    identity: &DeviceIdentity,
    workspace_id: WorkspaceId,
    setup_code: String,
) -> CreateAccountRequest {
    CreateAccountRequest {
        device: registration_for(identity, "air-laptop", DeviceRole::Client),
        workspace_id,
        workspace_name: WORKSPACE_NAME.to_owned(),
        sealed_workspace_key: SEALED_KEY_BYTES.to_vec(),
        setup_code,
    }
}

pub async fn create_account(test: &TestServer) -> Account {
    let owner = identity_from_seed(OWNER_SEED);
    let workspace_id = WorkspaceId(Uuid::new_v4());
    let setup_code = test.read_setup_code();
    let request = account_request_for(&owner, workspace_id, setup_code);
    let response = test
        .send_unsigned(
            axum::http::Method::POST,
            ACCOUNTS,
            crate::test_client::encode_json(&request),
        )
        .await;
    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    let _account_view: AccountView = response.json();
    Account {
        owner,
        workspace_id,
    }
}

pub async fn pair_device(
    test: &TestServer,
    account: &Account,
    identity: &DeviceIdentity,
    name: &str,
    role: DeviceRole,
) -> Device {
    let session = start_pairing(test, account).await;
    let registration = registration_for(identity, name, role);
    join_session(test, &session.code, registration.clone()).await;
    let response =
        approve_session(test, account, &session.code, &registration).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}

pub fn sample_project(workspace_id: WorkspaceId) -> Project {
    Project {
        id: ProjectId(Uuid::new_v4()),
        workspace_id,
        name: PROJECT_NAME.to_owned(),
        repositories: vec![Repository {
            address: "https://github.com/acme/app.git".to_owned(),
            default_branch: "main".to_owned(),
            agent_access: AgentAccess::ReadOnly,
        }],
    }
}

pub async fn create_project(test: &TestServer, account: &Account) -> Project {
    let request = SaveProjectRequest {
        project: sample_project(account.workspace_id),
    };
    let response = test.post(&account.owner, PROJECTS, &request).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}

pub fn one_agent_task(
    project_id: ProjectId,
    runs_on: RunnerTarget,
    schedule: Option<Schedule>,
) -> Task {
    Task {
        id: TaskId(Uuid::new_v4()),
        title: "Ship release 2.4".to_owned(),
        details: SEALED_DETAILS.to_owned(),
        place: TaskPlace::InProject { project_id },
        doer: TaskDoer::OneAgent {
            agent: AgentKind::ClaudeCode,
        },
        runs_on,
        agent_place: Some(AgentPlace::LocalProcess),
        skills: Vec::new(),
        uses_automatic_skills: true,
        approval_policy: ApprovalPolicy::AskBeforeRiskyActions,
        schedule,
        status: TaskStatus::ToDo,
        created_at: chrono::DateTime::from_timestamp(
            crate::test_client::START_TIME_SECONDS,
            0,
        )
        .expect("creation time is valid"),
    }
}

pub fn workspace_task(workspace_id: WorkspaceId) -> Task {
    let unplaced_project_id = ProjectId(Uuid::nil());
    let project_task =
        one_agent_task(unplaced_project_id, RunnerTarget::AnyFreeRunner, None);
    Task {
        place: TaskPlace::InWorkspace { workspace_id },
        agent_place: None,
        ..project_task
    }
}

pub async fn save_task(
    test: &TestServer,
    account: &Account,
    task: Task,
    start: TaskStart,
) -> TaskSaved {
    let request = SaveTaskRequest { task, start };
    let response = test.post(&account.owner, TASKS, &request).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}

pub fn heartbeat_with(
    labels: &[&str],
    slots_total: u32,
    slots_busy: u32,
) -> HeartbeatRequest {
    HeartbeatRequest {
        labels: labels.iter().map(|label| (*label).to_owned()).collect(),
        slots_total,
        slots_busy,
        link: RunnerLink::Direct,
        offers: vec![AgentPlace::Container, AgentPlace::LocalProcess],
        allowed_hosts: vec!["api.anthropic.com".to_owned()],
        cached_repositories: Vec::new(),
        held_tasks: Vec::new(),
    }
}

pub async fn send_heartbeat(
    test: &TestServer,
    identity: &DeviceIdentity,
    heartbeat: &HeartbeatRequest,
) -> Runner {
    let response = test.post(identity, RUNNER_HEARTBEAT, heartbeat).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}
