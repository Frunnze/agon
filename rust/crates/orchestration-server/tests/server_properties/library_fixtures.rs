use axum::http::StatusCode;
use orchestration_api::catalog::{SaveRuleRequest, SaveSkillRequest};
use orchestration_core::identifiers::{RuleId, SkillId};
use orchestration_core::library::{Rule, Skill, SkillSource, SkillUsage};
use orchestration_core::scope::Scope;
use uuid::Uuid;

use crate::fixtures::{Account, SEALED_DETAILS};
use crate::test_client::TestServer;

pub const MOST_ITEMS: usize = 5;
pub const CHANGED_DETAILS: &str = "sealed-v1:Y2hhbmdlZA";

pub fn sample_skill(name: &str) -> Skill {
    Skill {
        id: SkillId(Uuid::new_v4()),
        name: name.to_owned(),
        summary: "Ship the iOS app".to_owned(),
        instructions: SEALED_DETAILS.to_owned(),
        scope: Scope::everywhere(),
        usage: SkillUsage::Automatic,
        source: SkillSource::Created,
    }
}

pub fn sample_rule(title: &str, enabled: bool) -> Rule {
    Rule {
        id: RuleId(Uuid::new_v4()),
        title: title.to_owned(),
        details: SEALED_DETAILS.to_owned(),
        scope: Scope::everywhere(),
        enabled,
        added_at: chrono::DateTime::UNIX_EPOCH,
    }
}

pub fn skill_path(skill_id: SkillId) -> String {
    format!("/skills/{}", skill_id.0)
}

pub fn rule_path(rule_id: RuleId) -> String {
    format!("/rules/{}", rule_id.0)
}

pub async fn save_skill(test: &TestServer, account: &Account, skill: &Skill) {
    let request = SaveSkillRequest {
        skill: skill.clone(),
    };
    let response = test.post(&account.owner, "/skills", &request).await;
    assert_eq!(response.status, StatusCode::OK);
}

pub async fn save_rule(test: &TestServer, account: &Account, rule: &Rule) {
    let request = SaveRuleRequest { rule: rule.clone() };
    let response = test.post(&account.owner, "/rules", &request).await;
    assert_eq!(response.status, StatusCode::OK);
}

pub async fn list_skills(test: &TestServer, account: &Account) -> Vec<Skill> {
    test.get(&account.owner, "/skills").await.json()
}

pub async fn list_rules(test: &TestServer, account: &Account) -> Vec<Rule> {
    test.get(&account.owner, "/rules").await.json()
}
