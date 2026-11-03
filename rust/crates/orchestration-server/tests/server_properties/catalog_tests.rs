use axum::http::StatusCode;
use orchestration_api::catalog::{
    AddRepositoryRequest, SaveProjectRequest, SaveRuleRequest,
    SaveSkillRequest, SetRuleEnabledRequest,
};
use orchestration_core::identifiers::{RuleId, SkillId};
use orchestration_core::library::{
    Rule, Skill, SkillImprovement, SkillSource, SkillUsage,
};
use orchestration_core::scope::Scope;
use orchestration_core::workspace::{AgentAccess, Project, Repository};
use proptest::prelude::*;
use uuid::Uuid;

use crate::fixtures::{
    SEALED_DETAILS, create_account, create_project, sample_project,
};
use crate::test_client::{TestServer, block_on};

fn address_in_form(owner: &str, repository: &str, form: u8) -> String {
    match form {
        0 => format!("https://github.com/{owner}/{repository}.git"),
        1 => format!("github.com/{owner}/{repository}"),
        _ => format!("git@github.com:{owner}/{repository}.git"),
    }
}

fn sample_rule(enabled: bool) -> Rule {
    Rule {
        id: RuleId(Uuid::new_v4()),
        title: "Never push to main".to_owned(),
        details: SEALED_DETAILS.to_owned(),
        scope: Scope::everywhere(),
        enabled,
        added_at: chrono::DateTime::from_timestamp(0, 0)
            .expect("epoch is valid"),
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(16))]

    #[test]
    fn test_save_project_property_normalises_repository_addresses(
        owner in "[a-z][a-z0-9-]{0,10}",
        repository in "[a-z][a-z0-9_-]{0,10}",
        form in 0_u8..3,
    ) {
        let test = TestServer::start();
        let saved_project: Project = block_on(async {
            let account = create_account(&test).await;
            let mut project = sample_project(account.workspace_id);
            project.repositories[0].address =
                address_in_form(&owner, &repository, form);
            let request = SaveProjectRequest { project };
            test.post(&account.owner, "/projects", &request).await.json()
        });

        prop_assert_eq!(
            &saved_project.repositories[0].address,
            &format!("github.com/{owner}/{repository}")
        );
    }

    #[test]
    fn test_save_project_property_rejects_invalid_names(
        name in "[a-z]{0,3}[A-Z_ ][a-z]{0,3}",
    ) {
        let test = TestServer::start();
        let status = block_on(async {
            let account = create_account(&test).await;
            let mut project = sample_project(account.workspace_id);
            project.name = name;
            let request = SaveProjectRequest { project };
            test.post(&account.owner, "/projects", &request).await.status
        });

        prop_assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    }

    #[test]
    fn test_set_rule_enabled_property_keeps_the_last_choice(
        choices in proptest::collection::vec(any::<bool>(), 1..6),
    ) {
        let test = TestServer::start();
        let rules: Vec<Rule> = block_on(async {
            let account = create_account(&test).await;
            let rule = sample_rule(true);
            let request = SaveRuleRequest { rule: rule.clone() };
            let created = test.post(&account.owner, "/rules", &request).await;
            assert_eq!(created.status, StatusCode::OK);
            let enabled_path = format!("/rules/{}/enabled", rule.id.0);
            for enabled in &choices {
                let toggle = SetRuleEnabledRequest { enabled: *enabled };
                let response =
                    test.put(&account.owner, &enabled_path, &toggle).await;
                assert_eq!(response.status, StatusCode::OK);
            }
            test.get(&account.owner, "/rules").await.json()
        });

        prop_assert_eq!(rules.len(), 1);
        prop_assert_eq!(Some(&rules[0].enabled), choices.last());
    }
}

#[test]
fn repositories_are_added_once_in_canonical_form() {
    let test = TestServer::start();
    let (added, repeated_status) = block_on(async {
        let account = create_account(&test).await;
        let project = create_project(&test, &account).await;
        let path = format!("/projects/{}/repositories", project.id.0);
        let request = AddRepositoryRequest {
            repository: Repository {
                address: "git@github.com:acme/docs.git".to_owned(),
                default_branch: "main".to_owned(),
                agent_access: AgentAccess::PushAfterApproval,
            },
        };
        let added: Project =
            test.post(&account.owner, &path, &request).await.json();
        let repeated = test.post(&account.owner, &path, &request).await;
        (added, repeated.status)
    });

    let addresses: Vec<&str> = added
        .repositories
        .iter()
        .map(|repository| repository.address.as_str())
        .collect();
    assert_eq!(addresses, ["github.com/acme/app", "github.com/acme/docs"]);
    assert_eq!(repeated_status, StatusCode::CONFLICT);
}

#[test]
fn skills_are_saved_and_listed() {
    let test = TestServer::start();
    let (status, skills) = block_on(async {
        let account = create_account(&test).await;
        let skill = Skill {
            id: SkillId(Uuid::new_v4()),
            name: "ios-release".to_owned(),
            summary: "Ship the iOS app".to_owned(),
            instructions: SEALED_DETAILS.to_owned(),
            scope: Scope::everywhere(),
            usage: SkillUsage::Automatic,
            source: SkillSource::Created,
            improvement: SkillImprovement::Never,
            history: Vec::new(),
        };
        let request = SaveSkillRequest { skill };
        let response = test.post(&account.owner, "/skills", &request).await;
        let skills: Vec<Skill> =
            test.get(&account.owner, "/skills").await.json();
        (response.status, skills)
    });

    assert_eq!(status, StatusCode::OK);
    assert_eq!(skills.len(), 1);
    assert_eq!(skills[0].name, "ios-release");
}
