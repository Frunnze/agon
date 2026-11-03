use axum::http::StatusCode;
use orchestration_api::catalog::SaveProjectRequest;
use orchestration_api::routes::{PROJECTS, RUNNER_HEARTBEAT};
use orchestration_api::work::{ForgottenWork, HeartbeatRequest};
use orchestration_core::device::Runner;
use orchestration_core::identifiers::{ProjectId, TaskId, WorkspaceId};
use orchestration_core::workspace::{AgentAccess, Project, Repository};
use orchestration_security::identity::DeviceIdentity;
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::claim_fixtures::pair_runners;
use crate::deletion_fixtures::{
    assert_deleted, project_path, save_waiting_task, task_path,
};
use crate::fixtures::{
    Account, create_account, create_project, heartbeat_with,
};
use crate::test_client::{TestServer, block_on};

const FORGOTTEN_WORK_CASES: u32 = 8;
const RUNNER_SLOTS: u32 = 2;
const DOOMED_ADDRESS: &str = "github.com/acme/doomed";
const KEPT_ADDRESS: &str = "github.com/acme/kept";
const SHARED_ADDRESS: &str = "github.com/acme/shared";
const NEVER_USED_ADDRESS: &str = "github.com/acme/never-used";

fn project_with(workspace_id: WorkspaceId, addresses: &[&str]) -> Project {
    let mut repositories = Vec::new();
    for address in addresses {
        repositories.push(Repository {
            address: (*address).to_owned(),
            default_branch: "main".to_owned(),
            agent_access: AgentAccess::ReadOnly,
        });
    }
    Project {
        id: ProjectId(Uuid::new_v4()),
        workspace_id,
        name: format!("project-{}", Uuid::new_v4().simple()),
        repositories,
    }
}

async fn save_project_with(
    test: &TestServer,
    account: &Account,
    addresses: &[&str],
) -> Project {
    let request = SaveProjectRequest {
        project: project_with(account.workspace_id, addresses),
    };
    let response = test.post(&account.owner, PROJECTS, &request).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}

async fn answer_heartbeat(
    test: &TestServer,
    runner: &DeviceIdentity,
    heartbeat: &HeartbeatRequest,
) -> ForgottenWork {
    let response = test.post(runner, RUNNER_HEARTBEAT, heartbeat).await;
    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    response.json()
}

async fn first_runner(test: &TestServer, account: &Account) -> DeviceIdentity {
    let mut runners = pair_runners(test, account, 1, RUNNER_SLOTS).await;
    runners.remove(0)
}

fn holding(
    held_tasks: Vec<TaskId>,
    cached_repositories: &[&str],
) -> HeartbeatRequest {
    HeartbeatRequest {
        held_tasks,
        cached_repositories: cached_repositories
            .iter()
            .map(|address| (*address).to_owned())
            .collect(),
        ..heartbeat_with(&[], RUNNER_SLOTS, 0)
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FORGOTTEN_WORK_CASES))]

    #[test]
    fn test_receive_heartbeat_property_forgets_only_tasks_the_server_lacks(
        doomed_flags in vec(any::<bool>(), 1..5),
        unknown_count in 0_usize..3,
    ) {
        let test = TestServer::start();
        let (answer, expected_forgotten) = block_on(async {
            let account = create_account(&test).await;
            let runner = first_runner(&test, &account).await;
            let project = create_project(&test, &account).await;
            let mut held_tasks = Vec::new();
            let mut expected_forgotten = Vec::new();
            for is_doomed in &doomed_flags {
                let task =
                    save_waiting_task(&test, &account, project.id).await;
                held_tasks.push(task.id);
                if *is_doomed {
                    let path = task_path(task.id);
                    assert_deleted(&test.delete(&account.owner, &path).await);
                    expected_forgotten.push(task.id);
                }
            }
            for _ in 0..unknown_count {
                let unknown_task_id = TaskId(Uuid::new_v4());
                held_tasks.push(unknown_task_id);
                expected_forgotten.push(unknown_task_id);
            }
            let heartbeat = holding(held_tasks, &[]);
            let answer = answer_heartbeat(&test, &runner, &heartbeat).await;
            (answer, expected_forgotten)
        });

        prop_assert_eq!(answer.forgotten_tasks, expected_forgotten);
        prop_assert!(answer.unused_repositories.is_empty());
    }

    #[test]
    fn test_receive_heartbeat_property_names_repositories_no_project_uses(
        is_project_deleted in any::<bool>(),
        is_address_shared in any::<bool>(),
    ) {
        let test = TestServer::start();
        let answer = block_on(async {
            let account = create_account(&test).await;
            let runner = first_runner(&test, &account).await;
            let mut doomed_addresses = vec![DOOMED_ADDRESS];
            let mut kept_addresses = vec![KEPT_ADDRESS];
            if is_address_shared {
                doomed_addresses.push(SHARED_ADDRESS);
                kept_addresses.push(SHARED_ADDRESS);
            }
            let doomed =
                save_project_with(&test, &account, &doomed_addresses).await;
            save_project_with(&test, &account, &kept_addresses).await;
            if is_project_deleted {
                let path = project_path(doomed.id);
                assert_deleted(&test.delete(&account.owner, &path).await);
            }
            let cached = [
                DOOMED_ADDRESS,
                KEPT_ADDRESS,
                SHARED_ADDRESS,
                NEVER_USED_ADDRESS,
            ];
            let heartbeat = holding(Vec::new(), &cached);
            answer_heartbeat(&test, &runner, &heartbeat).await
        });

        let mut expected_unused = Vec::new();
        if is_project_deleted {
            expected_unused.push(DOOMED_ADDRESS.to_owned());
        }
        if !is_address_shared {
            expected_unused.push(SHARED_ADDRESS.to_owned());
        }
        expected_unused.push(NEVER_USED_ADDRESS.to_owned());
        prop_assert_eq!(answer.unused_repositories, expected_unused);
        prop_assert!(answer.forgotten_tasks.is_empty());
    }
}

#[test]
fn the_heartbeat_answer_still_describes_the_runner() {
    let test = TestServer::start();
    let runner_view = block_on(async {
        let account = create_account(&test).await;
        let runner = first_runner(&test, &account).await;
        let heartbeat = holding(vec![TaskId(Uuid::new_v4())], &[]);
        let response = test.post(&runner, RUNNER_HEARTBEAT, &heartbeat).await;
        response.json::<Runner>()
    });

    assert_eq!(runner_view.slots_total, RUNNER_SLOTS);
}
