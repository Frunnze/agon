use axum::http::StatusCode;
use orchestration_api::accounts::AccountView;
use orchestration_core::identifiers::{ProjectId, WorkspaceId};
use orchestration_core::library::Rule;
use orchestration_core::scope::{ProjectScope, Scope, WorkspaceScope};
use orchestration_core::workspace::{Project, Workspace};
use proptest::prelude::*;

use crate::deletion_fixtures::{
    assert_deleted, create_workspace, list_task_ids, project_path,
    read_last_audit_event, save_project_in, save_rule_with_scope,
    save_waiting_task, start_task, workspace_path,
};
use crate::fixtures::{create_account, create_project, one_agent_task};
use crate::test_client::{TestServer, block_on};

const DELETION_CASES: u32 = 8;
const DOOMED_WORKSPACE_NAME: &str = "personal";

fn only_projects(projects: Vec<ProjectId>) -> Scope {
    Scope {
        workspaces: WorkspaceScope::AllWorkspaces,
        projects: ProjectScope::OnlyProjects { projects },
    }
}

fn only_workspaces(workspaces: Vec<WorkspaceId>) -> Scope {
    Scope {
        workspaces: WorkspaceScope::OnlyWorkspaces { workspaces },
        projects: ProjectScope::AllProjects,
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DELETION_CASES))]

    #[test]
    fn test_delete_workspace_property_removes_its_projects_and_members(
        doomed_project_count in 0_usize..3,
        task_count in 0_usize..3,
    ) {
        let test = TestServer::start();
        let (workspaces, projects, tasks, account_view, kept) =
            block_on(async {
                let account = create_account(&test).await;
                let kept = create_project(&test, &account).await;
                let doomed_id = create_workspace(
                    &test,
                    &account,
                    DOOMED_WORKSPACE_NAME,
                )
                .await;
                for _ in 0..doomed_project_count {
                    let project =
                        save_project_in(&test, &account, doomed_id).await;
                    for _ in 0..task_count {
                        save_waiting_task(&test, &account, project.id).await;
                    }
                }
                assert_deleted(
                    &test
                        .delete(&account.owner, &workspace_path(doomed_id))
                        .await,
                );
                let workspaces: Vec<Workspace> =
                    test.get(&account.owner, "/workspaces").await.json();
                let projects: Vec<Project> =
                    test.get(&account.owner, "/projects").await.json();
                let tasks = list_task_ids(&test, &account).await;
                let account_view: AccountView =
                    test.get(&account.owner, "/accounts").await.json();
                (workspaces, projects, tasks, account_view, kept)
            });

        prop_assert_eq!(workspaces.len(), 1);
        prop_assert_eq!(projects.len(), 1);
        prop_assert_eq!(projects[0].id, kept.id);
        prop_assert!(tasks.is_empty());
        prop_assert_eq!(account_view.workspaces.len(), 1);
        prop_assert_eq!(account_view.sealed_workspace_keys.len(), 1);
    }

    #[test]
    fn test_delete_project_property_forgets_it_in_rule_scopes(
        listed_before in any::<bool>(),
    ) {
        let test = TestServer::start();
        let (rules, kept_id) = block_on(async {
            let account = create_account(&test).await;
            let doomed = create_project(&test, &account).await;
            let kept =
                save_project_in(&test, &account, account.workspace_id).await;
            let listed = if listed_before {
                vec![doomed.id, kept.id]
            } else {
                vec![kept.id, doomed.id]
            };
            save_rule_with_scope(&test, &account, only_projects(listed))
                .await;
            assert_deleted(
                &test.delete(&account.owner, &project_path(doomed.id)).await,
            );
            let rules: Vec<Rule> =
                test.get(&account.owner, "/rules").await.json();
            (rules, kept.id)
        });

        prop_assert_eq!(&rules[0].scope, &only_projects(vec![kept_id]));
    }
}

#[test]
fn deleting_a_workspace_forgets_it_in_rule_scopes() {
    let test = TestServer::start();
    let (rules, home_id, event) = block_on(async {
        let account = create_account(&test).await;
        let doomed_id =
            create_workspace(&test, &account, DOOMED_WORKSPACE_NAME).await;
        let scope = only_workspaces(vec![account.workspace_id, doomed_id]);
        save_rule_with_scope(&test, &account, scope).await;
        let path = workspace_path(doomed_id);
        assert_deleted(&test.delete(&account.owner, &path).await);
        let rules: Vec<Rule> = test.get(&account.owner, "/rules").await.json();
        let event = read_last_audit_event(&test, &account).await;
        (rules, account.workspace_id, event)
    });

    assert_eq!(rules[0].scope, only_workspaces(vec![home_id]));
    assert_eq!(event, "Deleted workspace personal");
}

#[test]
fn the_last_workspace_cannot_be_deleted() {
    let test = TestServer::start();
    let response = block_on(async {
        let account = create_account(&test).await;
        let path = workspace_path(account.workspace_id);
        test.delete(&account.owner, &path).await
    });

    assert_eq!(response.status, StatusCode::CONFLICT);
    assert_eq!(
        response.error_message(),
        "the last workspace cannot be deleted"
    );
}

#[test]
fn a_workspace_with_a_running_task_cannot_be_deleted() {
    let test = TestServer::start();
    let response = block_on(async {
        let account = create_account(&test).await;
        let doomed_id =
            create_workspace(&test, &account, DOOMED_WORKSPACE_NAME).await;
        let project = save_project_in(&test, &account, doomed_id).await;
        let task = one_agent_task(
            project.id,
            orchestration_core::device::RunnerTarget::AnyFreeRunner,
            None,
        );
        start_task(&test, &account, task).await;
        test.delete(&account.owner, &workspace_path(doomed_id))
            .await
    });

    assert_eq!(response.status, StatusCode::CONFLICT);
    assert_eq!(
        response.error_message(),
        "a task in workspace personal is running; cancel its run first"
    );
}
