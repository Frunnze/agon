use axum::http::StatusCode;
use orchestration_api::catalog::SaveSkillRequest;
use orchestration_core::approval::{ApprovalAction, ApprovalDecision};
use orchestration_core::library::{
    Skill, SkillChangeOrigin, SkillImprovement,
};
use proptest::prelude::*;

use crate::library_fixtures::{CHANGED_DETAILS, skill_path};
use crate::skill_improvement_fixtures::{
    PROPOSAL_SUMMARY, PROPOSED_INSTRUCTIONS, decide, list_approvals, propose,
    start_with_skill, stored_skill, undo_path,
};
use crate::test_client::{TestServer, block_on};

fn improvement() -> impl Strategy<Value = SkillImprovement> {
    prop_oneof![
        Just(SkillImprovement::Never),
        Just(SkillImprovement::AskMe),
        Just(SkillImprovement::Auto),
    ]
}

#[test]
fn a_skill_set_to_never_refuses_the_proposal_and_stays_the_same() {
    let test = TestServer::start();
    block_on(async {
        let improvable =
            start_with_skill(&test, SkillImprovement::Never).await;

        let status =
            propose(&test, &improvable.claimed.holder, &improvable).await;

        assert_eq!(status, StatusCode::FORBIDDEN);
        assert_eq!(stored_skill(&test, &improvable).await, improvable.skill);
        assert_eq!(list_approvals(&test, &improvable).await, Vec::new());
    });
}

#[test]
fn ask_me_raises_an_approval_and_keeps_the_skill_until_it_is_decided() {
    let test = TestServer::start();
    block_on(async {
        let improvable =
            start_with_skill(&test, SkillImprovement::AskMe).await;

        let status =
            propose(&test, &improvable.claimed.holder, &improvable).await;

        assert_eq!(status, StatusCode::NO_CONTENT);
        assert_eq!(stored_skill(&test, &improvable).await, improvable.skill);
        let approvals = list_approvals(&test, &improvable).await;
        assert_eq!(approvals.len(), 1);
        assert_eq!(approvals[0].run_id, Some(improvable.claimed.run.id));
        let expected_action = ApprovalAction::ImproveSkill {
            skill_id: improvable.skill.id,
            summary: PROPOSAL_SUMMARY.to_owned(),
            proposed_instructions: PROPOSED_INSTRUCTIONS.to_owned(),
        };
        assert_eq!(approvals[0].action, expected_action);
    });
}

#[test]
fn approving_an_improvement_saves_it_as_the_new_version() {
    let test = TestServer::start();
    block_on(async {
        let improvable =
            start_with_skill(&test, SkillImprovement::AskMe).await;
        propose(&test, &improvable.claimed.holder, &improvable).await;
        let approval = list_approvals(&test, &improvable).await.remove(0);

        let status =
            decide(&test, &improvable, &approval, ApprovalDecision::Approved)
                .await;

        assert_eq!(status, StatusCode::OK);
        let stored = stored_skill(&test, &improvable).await;
        assert_eq!(stored.instructions, PROPOSED_INSTRUCTIONS);
        let change = stored.history.last().expect("the change is recorded");
        let run_id = improvable.claimed.run.id;
        let expected_origin = SkillChangeOrigin::ApprovedAgentRun { run_id };
        assert_eq!(change.origin, expected_origin);
        assert_eq!(
            change.replaced_instructions,
            improvable.skill.instructions
        );
    });
}

#[test]
fn denying_an_improvement_keeps_the_skill() {
    let test = TestServer::start();
    block_on(async {
        let improvable =
            start_with_skill(&test, SkillImprovement::AskMe).await;
        propose(&test, &improvable.claimed.holder, &improvable).await;
        let approval = list_approvals(&test, &improvable).await.remove(0);

        let status =
            decide(&test, &improvable, &approval, ApprovalDecision::Denied)
                .await;

        assert_eq!(status, StatusCode::OK);
        assert_eq!(stored_skill(&test, &improvable).await, improvable.skill);
    });
}

#[test]
fn auto_saves_at_once_records_the_run_and_can_be_undone() {
    let test = TestServer::start();
    block_on(async {
        let improvable = start_with_skill(&test, SkillImprovement::Auto).await;

        let status =
            propose(&test, &improvable.claimed.holder, &improvable).await;

        assert_eq!(status, StatusCode::NO_CONTENT);
        assert_eq!(list_approvals(&test, &improvable).await, Vec::new());
        let stored = stored_skill(&test, &improvable).await;
        assert_eq!(stored.instructions, PROPOSED_INSTRUCTIONS);
        let run_id = improvable.claimed.run.id;
        let origins: Vec<SkillChangeOrigin> =
            stored.history.iter().map(|change| change.origin).collect();
        let expected = vec![SkillChangeOrigin::AutomaticAgentRun { run_id }];
        assert_eq!(origins, expected);

        let owner = &improvable.claimed.account.owner;
        let undo = test.post_empty(owner, &undo_path(&stored)).await;

        assert_eq!(undo.status, StatusCode::OK);
        let restored: Skill = undo.json();
        assert_eq!(restored, improvable.skill);
        assert_eq!(stored_skill(&test, &improvable).await, improvable.skill);
    });
}

#[test]
fn a_runner_without_a_step_of_the_run_cannot_propose() {
    let test = TestServer::start();
    block_on(async {
        let improvable = start_with_skill(&test, SkillImprovement::Auto).await;

        let status =
            propose(&test, &improvable.claimed.other, &improvable).await;

        assert_eq!(status, StatusCode::FORBIDDEN);
        assert_eq!(stored_skill(&test, &improvable).await, improvable.skill);
    });
}

#[test]
fn a_person_edit_is_recorded_only_when_the_instructions_change() {
    let test = TestServer::start();
    block_on(async {
        let improvable = start_with_skill(&test, SkillImprovement::Auto).await;
        let owner = &improvable.claimed.account.owner;
        let path = skill_path(improvable.skill.id);
        let renamed = Skill {
            name: "ios-ship".to_owned(),
            ..improvable.skill.clone()
        };
        let edited = Skill {
            instructions: CHANGED_DETAILS.to_owned(),
            ..renamed.clone()
        };

        for skill in [renamed, edited] {
            let request = SaveSkillRequest { skill };
            let response = test.put(owner, &path, &request).await;
            assert_eq!(response.status, StatusCode::OK);
        }

        let stored = stored_skill(&test, &improvable).await;
        let origins: Vec<SkillChangeOrigin> =
            stored.history.iter().map(|change| change.origin).collect();
        assert_eq!(origins, vec![SkillChangeOrigin::PersonEdit]);
        let undo = test.post_empty(owner, &undo_path(&stored)).await;
        assert_eq!(undo.status, StatusCode::CONFLICT);
    });
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(6))]

    #[test]
    fn test_improve_skill_property_follows_the_skill_setting(
        setting in improvement(),
    ) {
        let test = TestServer::start();
        let (stored, approvals, original) = block_on(async {
            let improvable = start_with_skill(&test, setting).await;
            propose(&test, &improvable.claimed.holder, &improvable).await;
            (
                stored_skill(&test, &improvable).await,
                list_approvals(&test, &improvable).await,
                improvable.skill,
            )
        });

        let is_saved = stored.instructions == PROPOSED_INSTRUCTIONS;
        prop_assert_eq!(is_saved, setting == SkillImprovement::Auto);
        let is_asked = approvals.len() == 1;
        prop_assert_eq!(is_asked, setting == SkillImprovement::AskMe);
        if !is_saved {
            prop_assert_eq!(stored, original);
        }
    }
}
