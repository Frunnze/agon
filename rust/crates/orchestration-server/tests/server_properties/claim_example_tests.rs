use std::collections::BTreeSet;
use std::sync::Arc;

use axum::http::StatusCode;
use orchestration_api::catalog::{SaveRuleRequest, SaveSkillRequest};
use orchestration_api::work::{SetAcceptingRunsRequest, TaskStart};
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{ProjectId, RuleId, SkillId};
use orchestration_core::library::{
    Rule, Skill, SkillImprovement, SkillSource, SkillUsage,
};
use orchestration_core::scope::{ProjectScope, Scope, WorkspaceScope};
use uuid::Uuid;

use crate::claim_fixtures::{claim, pair_runners, queue_runs};
use crate::fixtures::{
    SEALED_DETAILS, create_account, create_project, save_task,
};
use crate::test_client::{TestServer, block_on};

#[test]
fn concurrent_claims_never_share_a_run() {
    let test = Arc::new(TestServer::start());
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .worker_threads(4)
        .enable_all()
        .build()
        .expect("the runtime starts");
    let claimed_runs = runtime.block_on(async {
        let account = create_account(&test).await;
        let project = create_project(&test, &account).await;
        let runners = pair_runners(&test, &account, 3, 1).await;
        queue_runs(
            &test,
            &account,
            project.id,
            &RunnerTarget::AnyFreeRunner,
            2,
        )
        .await;
        let mut handles = Vec::new();
        for runner in runners {
            let shared_test = Arc::clone(&test);
            handles.push(tokio::spawn(async move {
                claim(&shared_test, &runner).await
            }));
        }
        let mut claimed_runs = Vec::new();
        for handle in handles {
            let response = handle.await.expect("the claim task finishes");
            claimed_runs.extend(response.assignment.map(|given| given.run.id));
        }
        claimed_runs
    });

    let distinct_runs: BTreeSet<_> = claimed_runs.iter().collect();
    assert_eq!(distinct_runs.len(), claimed_runs.len());
}

#[test]
fn runners_outside_the_workspace_and_paused_runners_get_nothing() {
    let test = TestServer::start();
    let (outsider_claim, paused_claim, resumed_claim) = block_on(async {
        let account = create_account(&test).await;
        let project = create_project(&test, &account).await;
        let runners = pair_runners(&test, &account, 1, 2).await;
        let runner_id = runners[0].device_id();
        let member_path = format!(
            "/workspaces/{}/devices/{}",
            account.workspace_id.0, runner_id.0
        );
        let removed = test.delete(&account.owner, &member_path).await;
        assert_eq!(removed.status, StatusCode::NO_CONTENT);
        queue_runs(
            &test,
            &account,
            project.id,
            &RunnerTarget::AnyFreeRunner,
            1,
        )
        .await;
        let outsider_claim = claim(&test, &runners[0]).await;
        let members_path =
            format!("/workspaces/{}/devices", account.workspace_id.0);
        let add_request =
            orchestration_api::catalog::AddWorkspaceDeviceRequest {
                device_id: runner_id.clone(),
                sealed_workspace_key: crate::fixtures::SEALED_KEY_BYTES
                    .to_vec(),
            };
        let added =
            test.post(&account.owner, &members_path, &add_request).await;
        assert_eq!(added.status, StatusCode::OK);
        let accepting_path = format!("/runners/{}/accepting", runner_id.0);
        let pause = SetAcceptingRunsRequest {
            accepting_new_runs: false,
        };
        let paused = test.put(&account.owner, &accepting_path, &pause).await;
        assert_eq!(paused.status, StatusCode::OK);
        let paused_claim = claim(&test, &runners[0]).await;
        let resume = SetAcceptingRunsRequest {
            accepting_new_runs: true,
        };
        test.put(&account.owner, &accepting_path, &resume).await;
        let resumed_claim = claim(&test, &runners[0]).await;
        (outsider_claim, paused_claim, resumed_claim)
    });

    assert!(outsider_claim.assignment.is_none());
    assert!(paused_claim.assignment.is_none());
    assert!(resumed_claim.assignment.is_some());
}

#[test]
fn assignments_carry_the_skills_and_rules_that_apply() {
    let test = TestServer::start();
    let assignment = block_on(async {
        let account = create_account(&test).await;
        let project = create_project(&test, &account).await;
        let runners = pair_runners(&test, &account, 1, 2).await;
        let elsewhere = Scope {
            workspaces: WorkspaceScope::AllWorkspaces,
            projects: ProjectScope::OnlyProjects {
                projects: vec![ProjectId(Uuid::new_v4())],
            },
        };
        for (name, scope) in [
            ("ios-release", Scope::everywhere()),
            ("docs-sync", elsewhere),
        ] {
            let skill = Skill {
                id: SkillId(Uuid::new_v4()),
                name: name.to_owned(),
                summary: name.to_owned(),
                instructions: SEALED_DETAILS.to_owned(),
                scope,
                usage: SkillUsage::Automatic,
                source: SkillSource::Created,
                improvement: SkillImprovement::Never,
                history: Vec::new(),
            };
            let request = SaveSkillRequest { skill };
            test.post(&account.owner, "/skills", &request).await;
        }
        let rule = Rule {
            id: RuleId(Uuid::new_v4()),
            title: "Never push to main".to_owned(),
            details: SEALED_DETAILS.to_owned(),
            scope: Scope::everywhere(),
            enabled: true,
            added_at: test.now(),
        };
        test.post(&account.owner, "/rules", &SaveRuleRequest { rule })
            .await;
        queue_runs(
            &test,
            &account,
            project.id,
            &RunnerTarget::AnyFreeRunner,
            1,
        )
        .await;
        claim(&test, &runners[0]).await.assignment
    });

    let assignment = assignment.expect("the runner gets the run");
    let skill_names: Vec<&str> = assignment
        .skills
        .iter()
        .map(|skill| skill.name.as_str())
        .collect();
    assert_eq!(skill_names, ["ios-release"]);
    assert_eq!(assignment.rules.len(), 1);
    let project = assignment.project.expect("a project task has its project");
    assert_eq!(project.name, "acme-app");
    assert!(assignment.workflow.is_none());
}

#[test]
fn workflow_steps_wait_for_their_upstream_step_and_their_runner() {
    let test = TestServer::start();
    let (early_claim, first_claim, second_claim) = block_on(async {
        let account = create_account(&test).await;
        let project = create_project(&test, &account).await;
        let runners = pair_runners(&test, &account, 2, 2).await;
        let first_target = RunnerTarget::SpecificRunner {
            device_id: runners[0].device_id(),
        };
        let second_target = RunnerTarget::SpecificRunner {
            device_id: runners[1].device_id(),
        };
        let workflow = crate::workflow_fixtures::release_workflow(
            crate::workflow_fixtures::workflow_agent("plan", first_target),
            crate::workflow_fixtures::workflow_agent(
                "build-ios",
                second_target,
            ),
        );
        let created = crate::workflow_fixtures::create_workflow(
            &test, &account, workflow,
        )
        .await;
        let document =
            orchestration_core::workflow_document::render_workflow_document(
                &created,
            );
        let signature = orchestration_security::documents::sign_document(
            &account.owner,
            &document,
        );
        let sign_path = format!("/workflows/{}/signature", created.id.0);
        let sign_request =
            orchestration_api::catalog::SignWorkflowRequest { signature };
        test.post(&account.owner, &sign_path, &sign_request).await;
        let task =
            crate::workflow_fixtures::workflow_task(project.id, created.id);
        save_task(&test, &account, task, TaskStart::Now).await;

        let early_claim = claim(&test, &runners[1]).await;
        let first_claim = claim(&test, &runners[0]).await;
        let run = first_claim
            .assignment
            .as_ref()
            .expect("the first runner gets plan")
            .run
            .clone();
        let finish = orchestration_api::work::RunEventsRequest {
            events: vec![orchestration_api::work::RunEvent::Finished],
        };
        let events_path = format!("/runs/{}/events", run.id.0);
        let finished = test.post(&runners[0], &events_path, &finish).await;
        assert_eq!(finished.status, StatusCode::OK);
        let second_claim = claim(&test, &runners[1]).await;
        (early_claim, first_claim, second_claim)
    });

    assert!(early_claim.assignment.is_none());
    let first_run = first_claim.assignment.expect("plan is given").run;
    let first_holders: Vec<Option<&str>> = first_run
        .steps
        .iter()
        .map(|step| step.runner.as_ref().map(|runner| runner.0.as_str()))
        .collect();
    assert!(first_holders[0].is_some());
    assert!(first_holders[1].is_none());
    let second_assignment =
        second_claim.assignment.expect("build-ios is given");
    assert!(second_assignment.workflow.is_some());
    assert!(second_assignment.run.steps[1].runner.is_some());
}
