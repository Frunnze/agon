use axum::http::StatusCode;
use orchestration_api::catalog::ImproveSkillRequest;
use orchestration_api::work::DecideApprovalRequest;
use orchestration_core::approval::{ApprovalDecision, ApprovalRequest};
use orchestration_core::library::{Skill, SkillImprovement};
use orchestration_security::decisions::sign_decision;
use orchestration_security::identity::DeviceIdentity;

use crate::library_fixtures::{list_skills, sample_skill, save_skill};
use crate::run_fixtures::{ClaimedRun, start_claimed_run};
use crate::test_client::TestServer;

pub const PROPOSED_INSTRUCTIONS: &str = "sealed-v1:aW1wcm92ZWQ";
pub const PROPOSAL_SUMMARY: &str = "2 lines added, 1 line removed";

#[derive(Debug)]
pub struct ImprovableSkill {
    pub claimed: ClaimedRun,
    pub skill: Skill,
}

pub async fn start_with_skill(
    test: &TestServer,
    improvement: SkillImprovement,
) -> ImprovableSkill {
    let claimed = start_claimed_run(test).await;
    let skill = Skill {
        improvement,
        ..sample_skill("ios-release")
    };
    save_skill(test, &claimed.account, &skill).await;
    ImprovableSkill { claimed, skill }
}

pub fn improvement_path(skill: &Skill) -> String {
    format!("/skills/{}/improvements", skill.id.0)
}

pub fn undo_path(skill: &Skill) -> String {
    format!("/skills/{}/undo", skill.id.0)
}

pub async fn propose(
    test: &TestServer,
    runner: &DeviceIdentity,
    improvable: &ImprovableSkill,
) -> StatusCode {
    let request = ImproveSkillRequest {
        run_id: improvable.claimed.run.id,
        summary: PROPOSAL_SUMMARY.to_owned(),
        instructions: PROPOSED_INSTRUCTIONS.to_owned(),
    };
    let path = improvement_path(&improvable.skill);
    test.post(runner, &path, &request).await.status
}

pub async fn stored_skill(
    test: &TestServer,
    improvable: &ImprovableSkill,
) -> Skill {
    let skills = list_skills(test, &improvable.claimed.account).await;
    skills
        .into_iter()
        .find(|skill| skill.id == improvable.skill.id)
        .expect("the skill is still stored")
}

pub async fn list_approvals(
    test: &TestServer,
    improvable: &ImprovableSkill,
) -> Vec<ApprovalRequest> {
    let owner = &improvable.claimed.account.owner;
    test.get(owner, "/approvals").await.json()
}

pub async fn decide(
    test: &TestServer,
    improvable: &ImprovableSkill,
    approval: &ApprovalRequest,
    decision: ApprovalDecision,
) -> StatusCode {
    let owner = &improvable.claimed.account.owner;
    let signed = sign_decision(owner, approval, decision, test.now())
        .expect("the decision signs");
    let request = DecideApprovalRequest { decision: signed };
    let path = format!("/approvals/{}/decision", approval.id.0);
    test.post(owner, &path, &request).await.status
}
