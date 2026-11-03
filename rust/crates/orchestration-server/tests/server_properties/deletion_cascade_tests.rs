use std::collections::BTreeSet;

use orchestration_api::catalog::WorkflowListing;
use orchestration_api::work::TaskStart;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{
    RuleId, SkillId, WorkflowId, WorkspaceId,
};
use orchestration_core::library::{Rule, Skill};
use orchestration_core::scope::{ProjectScope, Scope, WorkspaceScope};
use orchestration_core::task::{Schedule, Task};
use orchestration_core::workflow::Workflow;
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::deletion_fixtures::{
    assert_deleted, create_workspace, nightly_schedule, save_rule_with_scope,
    workspace_path,
};
use crate::fixtures::{
    Account, create_account, create_project, one_agent_task, save_task,
};
use crate::library_fixtures::{
    list_rules, list_skills, sample_skill, save_skill, skill_path,
};
use crate::test_client::{TestServer, block_on};
use crate::workflow_fixtures::{
    create_workflow, release_workflow, workflow_agent,
};

const CASCADE_CASES: u32 = 8;
const DOOMED_WORKSPACE_NAME: &str = "personal";

#[derive(Clone, Copy, Debug)]
struct ChosenSkills {
    chooses_doomed: bool,
    chooses_kept: bool,
    is_job: bool,
}

fn any_chosen_skills() -> impl Strategy<Value = ChosenSkills> {
    (any::<bool>(), any::<bool>(), any::<bool>()).prop_map(
        |(chooses_doomed, chooses_kept, is_job)| ChosenSkills {
            chooses_doomed,
            chooses_kept,
            is_job,
        },
    )
}

fn list_chosen(
    choice: ChosenSkills,
    doomed_id: SkillId,
    kept_id: SkillId,
) -> Vec<SkillId> {
    let mut chosen = Vec::new();
    if choice.chooses_doomed {
        chosen.push(doomed_id);
    }
    if choice.chooses_kept {
        chosen.push(kept_id);
    }
    chosen
}

fn schedule_for(choice: ChosenSkills) -> Option<Schedule> {
    if choice.is_job {
        return Some(nightly_schedule());
    }
    None
}

fn scoped_to(workspaces: Vec<WorkspaceId>) -> Scope {
    Scope {
        workspaces: WorkspaceScope::OnlyWorkspaces { workspaces },
        projects: ProjectScope::AllProjects,
    }
}

fn workflow_available_in(
    name: &str,
    availability: WorkspaceScope,
) -> Workflow {
    let first = workflow_agent("plan", RunnerTarget::AnyFreeRunner);
    let second = workflow_agent("build", RunnerTarget::AnyFreeRunner);
    Workflow {
        name: name.to_owned(),
        availability,
        ..release_workflow(first, second)
    }
}

async fn save_skill_with_scope(
    test: &TestServer,
    account: &Account,
    name: &str,
    scope: Scope,
) -> Skill {
    let skill = Skill {
        scope,
        ..sample_skill(name)
    };
    save_skill(test, account, &skill).await;
    skill
}

async fn list_tasks(test: &TestServer, account: &Account) -> Vec<Task> {
    test.get(&account.owner, "/tasks").await.json()
}

async fn list_workflow_ids(
    test: &TestServer,
    account: &Account,
) -> BTreeSet<WorkflowId> {
    let listings: Vec<WorkflowListing> =
        test.get(&account.owner, "/workflows").await.json();
    listings.iter().map(|listing| listing.workflow.id).collect()
}

#[derive(Debug, PartialEq, Eq)]
struct LibraryItems {
    skill_ids: BTreeSet<SkillId>,
    rule_ids: BTreeSet<RuleId>,
    workflow_ids: BTreeSet<WorkflowId>,
    task_skills: Vec<SkillId>,
}

fn order_workspaces(
    home_id: WorkspaceId,
    doomed_id: WorkspaceId,
    is_home_listed_first: bool,
) -> Vec<WorkspaceId> {
    if is_home_listed_first {
        return vec![home_id, doomed_id];
    }
    vec![doomed_id, home_id]
}

async fn delete_workspace_holding_library(
    test: &TestServer,
    is_home_listed_first: bool,
) -> (LibraryItems, LibraryItems) {
    let account = create_account(test).await;
    let home_id = account.workspace_id;
    let doomed_id =
        create_workspace(test, &account, DOOMED_WORKSPACE_NAME).await;
    let both_workspaces =
        order_workspaces(home_id, doomed_id, is_home_listed_first);
    let only_doomed = scoped_to(vec![doomed_id]);
    let both = scoped_to(both_workspaces.clone());

    let doomed_skill =
        save_skill_with_scope(test, &account, "doomed", only_doomed.clone())
            .await;
    let shared_skill =
        save_skill_with_scope(test, &account, "shared", both.clone()).await;
    let everywhere_skill =
        save_skill_with_scope(test, &account, "anywhere", Scope::everywhere())
            .await;
    save_rule_with_scope(test, &account, only_doomed).await;
    let shared_rule = save_rule_with_scope(test, &account, both).await;
    let everywhere_rule =
        save_rule_with_scope(test, &account, Scope::everywhere()).await;

    let doomed_only = WorkspaceScope::OnlyWorkspaces {
        workspaces: vec![doomed_id],
    };
    let shared = WorkspaceScope::OnlyWorkspaces {
        workspaces: both_workspaces,
    };
    let doomed_workflow = workflow_available_in("doomed-flow", doomed_only);
    create_workflow(test, &account, doomed_workflow).await;
    let shared_workflow = create_workflow(
        test,
        &account,
        workflow_available_in("shared-flow", shared),
    )
    .await;
    let everywhere_workflow = create_workflow(
        test,
        &account,
        workflow_available_in("anywhere-flow", WorkspaceScope::AllWorkspaces),
    )
    .await;

    let project = create_project(test, &account).await;
    let task = Task {
        skills: vec![doomed_skill.id, shared_skill.id],
        ..one_agent_task(project.id, RunnerTarget::AnyFreeRunner, None)
    };
    save_task(test, &account, task, TaskStart::Later).await;

    assert_deleted(
        &test
            .delete(&account.owner, &workspace_path(doomed_id))
            .await,
    );

    let leftovers = LibraryItems {
        skill_ids: list_skills(test, &account)
            .await
            .iter()
            .map(|skill| skill.id)
            .collect(),
        rule_ids: list_rules(test, &account)
            .await
            .iter()
            .map(|rule: &Rule| rule.id)
            .collect(),
        workflow_ids: list_workflow_ids(test, &account).await,
        task_skills: list_tasks(test, &account).await[0].skills.clone(),
    };
    let kept = LibraryItems {
        skill_ids: BTreeSet::from([shared_skill.id, everywhere_skill.id]),
        rule_ids: BTreeSet::from([shared_rule.id, everywhere_rule.id]),
        workflow_ids: BTreeSet::from([
            shared_workflow.id,
            everywhere_workflow.id,
        ]),
        task_skills: vec![shared_skill.id],
    };
    (leftovers, kept)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CASCADE_CASES))]

    #[test]
    fn test_delete_skill_property_removes_it_from_every_task_and_job(
        choices in vec(any_chosen_skills(), 1..5),
    ) {
        let test = TestServer::start();
        let (tasks, skills, doomed_id, kept_id) = block_on(async {
            let account = create_account(&test).await;
            let project = create_project(&test, &account).await;
            let doomed = sample_skill("doomed");
            let kept = sample_skill("kept");
            save_skill(&test, &account, &doomed).await;
            save_skill(&test, &account, &kept).await;
            for choice in &choices {
                let task = Task {
                    skills: list_chosen(*choice, doomed.id, kept.id),
                    ..one_agent_task(
                        project.id,
                        RunnerTarget::AnyFreeRunner,
                        schedule_for(*choice),
                    )
                };
                save_task(&test, &account, task, TaskStart::Later).await;
            }
            let path = skill_path(doomed.id);
            assert_deleted(&test.delete(&account.owner, &path).await);
            let tasks = list_tasks(&test, &account).await;
            let skills = list_skills(&test, &account).await;
            (tasks, skills, doomed.id, kept.id)
        });

        prop_assert_eq!(tasks.len(), choices.len());
        for task in &tasks {
            prop_assert!(!task.skills.contains(&doomed_id));
        }
        let kept_choices = choices
            .iter()
            .filter(|choice| choice.chooses_kept)
            .count();
        let tasks_keeping = tasks
            .iter()
            .filter(|task| task.skills == vec![kept_id])
            .count();
        prop_assert_eq!(tasks_keeping, kept_choices);
        prop_assert_eq!(skills.len(), 1);
        prop_assert_eq!(skills[0].id, kept_id);
    }

    #[test]
    fn test_delete_workspace_property_removes_the_library_only_it_held(
        is_home_listed_first in any::<bool>(),
    ) {
        let test = TestServer::start();
        let (leftovers, kept) = block_on(delete_workspace_holding_library(
            &test,
            is_home_listed_first,
        ));

        prop_assert_eq!(leftovers, kept);
    }
}

#[test]
fn a_skill_unknown_to_the_server_cannot_be_deleted() {
    let test = TestServer::start();
    let status = block_on(async {
        let account = create_account(&test).await;
        let path = skill_path(SkillId(Uuid::new_v4()));
        test.delete(&account.owner, &path).await.status
    });

    assert_eq!(status, axum::http::StatusCode::NOT_FOUND);
}
