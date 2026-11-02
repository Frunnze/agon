use axum::http::StatusCode;
use orchestration_api::catalog::{SaveRuleRequest, SaveSkillRequest};
use orchestration_api::updates::AuditView;
use orchestration_core::library::{Rule, Skill};

use crate::fixtures::create_account;
use crate::library_fixtures::{
    list_rules, list_skills, rule_path, sample_rule, sample_skill, save_rule,
    save_skill, skill_path,
};
use crate::test_client::{TestServer, block_on};

#[test]
fn editing_an_unknown_item_is_refused() {
    let test = TestServer::start();
    let statuses = block_on(async {
        let account = create_account(&test).await;
        let skill = sample_skill("ios-release");
        let rule = sample_rule("Keep commits small", true);
        let skill_request = SaveSkillRequest {
            skill: skill.clone(),
        };
        let rule_request = SaveRuleRequest { rule: rule.clone() };
        let skill_response = test
            .put(&account.owner, &skill_path(skill.id), &skill_request)
            .await;
        let rule_response = test
            .put(&account.owner, &rule_path(rule.id), &rule_request)
            .await;
        [skill_response.status, rule_response.status]
    });

    assert_eq!(statuses, [StatusCode::NOT_FOUND, StatusCode::NOT_FOUND]);
}

#[test]
fn an_edit_addressed_to_another_stored_item_is_refused() {
    let test = TestServer::start();
    let (skill_status, rule_status, skills, rules) = block_on(async {
        let account = create_account(&test).await;
        let first_skill = sample_skill("ios-release");
        let second_skill = sample_skill("code-review");
        let first_rule = sample_rule("Keep commits small", true);
        let second_rule = sample_rule("Never push to main", true);
        for skill in [&first_skill, &second_skill] {
            save_skill(&test, &account, skill).await;
        }
        for rule in [&first_rule, &second_rule] {
            save_rule(&test, &account, rule).await;
        }
        let skill_request = SaveSkillRequest { skill: first_skill };
        let rule_request = SaveRuleRequest { rule: first_rule };
        let skill_response = test
            .put(&account.owner, &skill_path(second_skill.id), &skill_request)
            .await;
        let rule_response = test
            .put(&account.owner, &rule_path(second_rule.id), &rule_request)
            .await;
        (
            skill_response.status,
            rule_response.status,
            list_skills(&test, &account).await,
            list_rules(&test, &account).await,
        )
    });

    assert_eq!(skill_status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(rule_status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(skills.len(), 2);
    assert_eq!(rules.len(), 2);
}

#[test]
fn skill_and_rule_edits_are_audited_and_kept_across_restarts() {
    let test = TestServer::start();
    let (audit_view, account) = block_on(async {
        let account = create_account(&test).await;
        let skill = sample_skill("ios-release");
        let rule = sample_rule("Keep commits small", true);
        save_skill(&test, &account, &skill).await;
        save_rule(&test, &account, &rule).await;
        let renamed_skill = Skill {
            name: "ios-ship".to_owned(),
            ..skill.clone()
        };
        let renamed_rule = Rule {
            title: "Keep commits tiny".to_owned(),
            ..rule.clone()
        };
        let skill_request = SaveSkillRequest {
            skill: renamed_skill,
        };
        let rule_request = SaveRuleRequest { rule: renamed_rule };
        test.put(&account.owner, &skill_path(skill.id), &skill_request)
            .await;
        test.put(&account.owner, &rule_path(rule.id), &rule_request)
            .await;
        test.delete(&account.owner, &skill_path(skill.id)).await;
        test.delete(&account.owner, &rule_path(rule.id)).await;
        let audit_view: AuditView =
            test.get(&account.owner, "/audit").await.json();
        (audit_view, account)
    });
    let restarted = test.restart();
    let (skills, rules) = block_on(async {
        (
            list_skills(&restarted, &account).await,
            list_rules(&restarted, &account).await,
        )
    });

    let events: Vec<&str> = audit_view
        .entries
        .iter()
        .map(|entry| entry.event.as_str())
        .collect();
    assert_eq!(
        events[events.len() - 6..],
        [
            "Saved skill ios-release",
            "Added rule Keep commits small",
            "Changed skill ios-ship",
            "Changed rule Keep commits tiny",
            "Deleted skill ios-ship",
            "Deleted rule Keep commits tiny",
        ]
    );
    assert_eq!(skills, Vec::<Skill>::new());
    assert_eq!(rules, Vec::<Rule>::new());
}
