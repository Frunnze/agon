use axum::http::StatusCode;
use orchestration_api::catalog::{AddRepositoryRequest, SaveProjectRequest};
use orchestration_api::routes::PROJECTS;
use orchestration_api::work::RunAssignment;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::DeviceId;
use orchestration_core::local_folders::{LocalFolder, render_local_address};
use orchestration_core::workspace::{AgentAccess, Project, Repository};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::claim_fixtures::{claim, pair_runners, queue_runs};
use crate::fixtures::{create_account, sample_project};
use crate::test_client::{TestServer, block_on};

const MAXIMUM_RUNNERS: u8 = 4;
const MAXIMUM_RUNS: usize = 3;
const MAXIMUM_CLAIMS: usize = 16;

fn any_folder_path() -> impl Strategy<Value = String> {
    "(/[A-Za-z0-9_-]{1,8}){1,4}"
}

fn folder_repository(device_id: &DeviceId, path: &str) -> Repository {
    let folder = LocalFolder {
        device_id: device_id.clone(),
        path: path.to_owned(),
    };
    Repository {
        address: render_local_address(&folder)
            .expect("generated folders are valid"),
        default_branch: "main".to_owned(),
        agent_access: AgentAccess::PushAfterApproval,
    }
}

fn project_with(project: Project, extra: Repository) -> Project {
    let mut repositories = project.repositories.clone();
    repositories.push(extra);
    Project {
        repositories,
        ..project
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(12))]

    #[test]
    fn test_save_project_property_keeps_a_folder_in_canonical_form(
        path in any_folder_path(),
    ) {
        let test = TestServer::start();
        let (status, saved) = block_on(async {
            let account = create_account(&test).await;
            let owner_id = account.owner.device_id();
            let typed = format!("{path}/");
            let repository = folder_repository(&owner_id, &path);
            let typed_repository = Repository {
                address: repository.address.replace(&path, &typed),
                ..repository
            };
            let project = project_with(
                sample_project(account.workspace_id),
                typed_repository,
            );
            let request = SaveProjectRequest { project };
            let response = test.post(&account.owner, PROJECTS, &request).await;
            let saved: Option<Project> =
                (response.status == StatusCode::OK).then(|| response.json());
            (response.status, saved)
        });

        let saved = saved.ok_or_else(|| TestCaseError::fail("not saved"))?;
        prop_assert_eq!(status, StatusCode::OK);
        prop_assert!(saved.repositories[1].address.ends_with(&path));
    }

    #[test]
    fn test_save_project_property_folders_on_two_devices_are_refused(
        first_path in any_folder_path(),
        second_path in any_folder_path(),
    ) {
        let test = TestServer::start();
        let status = block_on(async {
            let account = create_account(&test).await;
            let first = DeviceId("aa11".to_owned());
            let second = DeviceId("bb22".to_owned());
            let project = project_with(
                project_with(
                    sample_project(account.workspace_id),
                    folder_repository(&first, &first_path),
                ),
                folder_repository(&second, &second_path),
            );
            let request = SaveProjectRequest { project };
            test.post(&account.owner, PROJECTS, &request).await.status
        });

        prop_assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    }

    #[test]
    fn test_add_repository_property_folder_of_another_device_is_refused(
        first_path in any_folder_path(),
        second_path in any_folder_path(),
    ) {
        let test = TestServer::start();
        let status = block_on(async {
            let account = create_account(&test).await;
            let first = DeviceId("aa11".to_owned());
            let second = DeviceId("bb22".to_owned());
            let project = project_with(
                sample_project(account.workspace_id),
                folder_repository(&first, &first_path),
            );
            let save = SaveProjectRequest {
                project: project.clone(),
            };
            test.post(&account.owner, PROJECTS, &save).await;
            let path = format!("/projects/{}/repositories", project.id.0);
            let request = AddRepositoryRequest {
                repository: folder_repository(&second, &second_path),
            };
            test.post(&account.owner, &path, &request).await.status
        });

        prop_assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    }

    #[test]
    fn test_claim_next_run_property_only_the_folder_device_claims(
        runner_count in 1_u8..MAXIMUM_RUNNERS,
        holder_seed in 0_usize..usize::from(MAXIMUM_RUNNERS),
        run_count in 1_usize..MAXIMUM_RUNS,
        claim_order in vec(0_usize..4, 0..MAXIMUM_CLAIMS),
        path in any_folder_path(),
    ) {
        let holder_position = holder_seed % usize::from(runner_count);
        let holder_claims = claim_order.iter().any(|runner_position| {
            runner_position % usize::from(runner_count) == holder_position
        });
        let test = TestServer::start();
        let (holder_id, assignments) = block_on(async {
            let account = create_account(&test).await;
            let runners = pair_runners(&test, &account, runner_count, 8).await;
            let holder_id = runners[holder_position].device_id();
            let project = project_with(
                sample_project(account.workspace_id),
                folder_repository(&holder_id, &path),
            );
            let save = SaveProjectRequest {
                project: project.clone(),
            };
            test.post(&account.owner, PROJECTS, &save).await;
            let target = RunnerTarget::AnyFreeRunner;
            queue_runs(&test, &account, project.id, &target, run_count).await;
            let mut assignments: Vec<RunAssignment> = Vec::new();
            for runner_position in claim_order {
                let runner = &runners[runner_position % runners.len()];
                assignments.extend(claim(&test, runner).await.assignment);
            }
            (holder_id, assignments)
        });

        prop_assert_eq!(!assignments.is_empty(), holder_claims);
        for assignment in &assignments {
            let runner = assignment.run.steps[0].runner.as_ref();
            prop_assert_eq!(runner, Some(&holder_id));
        }
    }

    #[test]
    fn test_claim_next_run_property_waits_while_the_folder_has_no_runner(
        runner_count in 1_u8..MAXIMUM_RUNNERS,
        claim_order in vec(0_usize..4, 1..MAXIMUM_CLAIMS),
        path in any_folder_path(),
    ) {
        let test = TestServer::start();
        let assignments = block_on(async {
            let account = create_account(&test).await;
            let runners = pair_runners(&test, &account, runner_count, 8).await;
            let owner_id = account.owner.device_id();
            let project = project_with(
                sample_project(account.workspace_id),
                folder_repository(&owner_id, &path),
            );
            let save = SaveProjectRequest {
                project: project.clone(),
            };
            test.post(&account.owner, PROJECTS, &save).await;
            let target = RunnerTarget::AnyFreeRunner;
            queue_runs(&test, &account, project.id, &target, 1).await;
            let mut assignments: Vec<RunAssignment> = Vec::new();
            for runner_position in claim_order {
                let runner = &runners[runner_position % runners.len()];
                assignments.extend(claim(&test, runner).await.assignment);
            }
            assignments
        });

        prop_assert!(assignments.is_empty());
    }
}
