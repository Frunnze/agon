use axum::http::StatusCode;
use orchestration_core::approval::ApprovalAction;
use orchestration_core::library::SkillImprovement;
use proptest::prelude::*;

use crate::approval_ending_support::{
    SUMMARY_PATTERN, ask_during, ask_while_running, choose_decision,
    decide_approval, end_run, find_listed, list_approvals, run_ending,
};
use crate::skill_improvement_fixtures::{propose, start_with_skill};
use crate::test_client::{TestServer, block_on};

proptest! {
    #![proptest_config(ProptestConfig::with_cases(4))]

    #[test]
    fn test_asks_about_finished_run_property_a_decided_question_stays(
        summary in SUMMARY_PATTERN,
        ending in run_ending(),
        is_approved in any::<bool>(),
    ) {
        let test = TestServer::start();

        let (status, shown_decision) = block_on(async {
            let (claimed, approval) = ask_while_running(&test, &summary).await;
            let owner = &claimed.account.owner;
            let decision = choose_decision(is_approved);
            let status =
                decide_approval(&test, owner, &approval, decision).await;
            end_run(&test, &claimed, ending).await;
            let to_person = list_approvals(&test, owner).await;
            let shown = find_listed(&to_person, &approval);
            let shown_decision = shown
                .and_then(|listed| listed.decision.as_ref())
                .map(|signed| signed.decision);
            (status, shown_decision)
        });

        prop_assert_eq!(status, StatusCode::OK);
        prop_assert_eq!(shown_decision, Some(choose_decision(is_approved)));
    }

    #[test]
    fn test_asks_about_finished_run_property_a_skill_proposal_stays_open(
        ending in run_ending(),
        is_approved in any::<bool>(),
    ) {
        let test = TestServer::start();

        let (proposal_status, shown_proposals, decided_status) =
            block_on(async {
                let improvable =
                    start_with_skill(&test, SkillImprovement::AskMe).await;
                let claimed = &improvable.claimed;
                let owner = &claimed.account.owner;
                let proposal_status =
                    propose(&test, &claimed.holder, &improvable).await;
                end_run(&test, claimed, ending).await;
                let shown_proposals = list_approvals(&test, owner).await;
                let decision = choose_decision(is_approved);
                let proposal = shown_proposals[0].clone();
                let decided_status =
                    decide_approval(&test, owner, &proposal, decision).await;
                (proposal_status, shown_proposals, decided_status)
            });

        prop_assert_eq!(proposal_status, StatusCode::NO_CONTENT);
        let [shown] = shown_proposals.as_slice() else {
            return Err(TestCaseError::fail("one proposal is listed"));
        };
        let is_skill_proposal =
            matches!(shown.action, ApprovalAction::ImproveSkill { .. });
        prop_assert!(is_skill_proposal);
        prop_assert_eq!(decided_status, StatusCode::OK);
    }

    #[test]
    fn test_asks_about_finished_run_property_only_the_open_question_hides(
        summary in SUMMARY_PATTERN,
        ending in run_ending(),
        is_approved in any::<bool>(),
    ) {
        let test = TestServer::start();

        let (decided, open, shown_to_person) = block_on(async {
            let (claimed, decided) = ask_while_running(&test, &summary).await;
            let owner = &claimed.account.owner;
            let decision = choose_decision(is_approved);
            decide_approval(&test, owner, &decided, decision).await;
            let open = ask_during(&test, &claimed, &summary).await;
            end_run(&test, &claimed, ending).await;
            let shown_to_person = list_approvals(&test, owner).await;
            (decided, open, shown_to_person)
        });

        prop_assert!(find_listed(&shown_to_person, &decided).is_some());
        prop_assert!(find_listed(&shown_to_person, &open).is_none());
    }
}
