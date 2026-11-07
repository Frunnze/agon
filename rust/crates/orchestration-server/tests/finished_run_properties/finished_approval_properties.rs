use axum::http::StatusCode;
use proptest::prelude::*;

use crate::approval_ending_support::{
    SUMMARY_PATTERN, ask_while_running, choose_decision, decide_approval,
    end_run, find_listed, list_approvals, run_ending,
};
use crate::test_client::{TestServer, block_on};

proptest! {
    #![proptest_config(ProptestConfig::with_cases(4))]

    #[test]
    fn test_visible_approvals_property_hides_questions_of_finished_runs(
        summary in SUMMARY_PATTERN,
        ending in run_ending(),
    ) {
        let test = TestServer::start();

        let (shown_to_person, shown_to_runner) = block_on(async {
            let (claimed, approval) = ask_while_running(&test, &summary).await;
            end_run(&test, &claimed, ending).await;
            let owner = &claimed.account.owner;
            let to_person = list_approvals(&test, owner).await;
            let to_runner = list_approvals(&test, &claimed.holder).await;
            let shown_to_person = find_listed(&to_person, &approval).cloned();
            let shown_to_runner = find_listed(&to_runner, &approval).cloned();
            (shown_to_person, shown_to_runner)
        });

        prop_assert_eq!(shown_to_person, None);
        prop_assert!(shown_to_runner.is_some());
    }

    #[test]
    fn test_visible_approvals_property_shows_questions_of_running_runs(
        summary in SUMMARY_PATTERN,
    ) {
        let test = TestServer::start();

        let (approval, shown_to_person) = block_on(async {
            let (claimed, approval) = ask_while_running(&test, &summary).await;
            let owner = &claimed.account.owner;
            let to_person = list_approvals(&test, owner).await;
            let shown_to_person = find_listed(&to_person, &approval).cloned();
            (approval, shown_to_person)
        });

        prop_assert_eq!(shown_to_person, Some(approval));
    }

    #[test]
    fn test_visible_approvals_property_the_runner_sees_only_its_own(
        summary in SUMMARY_PATTERN,
        ending in run_ending(),
    ) {
        let test = TestServer::start();

        let (shown_to_holder, shown_to_other) = block_on(async {
            let (claimed, approval) = ask_while_running(&test, &summary).await;
            end_run(&test, &claimed, ending).await;
            let to_holder = list_approvals(&test, &claimed.holder).await;
            let to_other = list_approvals(&test, &claimed.other).await;
            let shown_to_holder = find_listed(&to_holder, &approval).cloned();
            (shown_to_holder, to_other)
        });

        prop_assert!(shown_to_holder.is_some());
        prop_assert!(shown_to_other.is_empty());
    }

    #[test]
    fn test_record_decision_property_refuses_questions_of_finished_runs(
        summary in SUMMARY_PATTERN,
        ending in run_ending(),
        is_approved in any::<bool>(),
    ) {
        let test = TestServer::start();

        let (status, stored_decision) = block_on(async {
            let (claimed, approval) = ask_while_running(&test, &summary).await;
            end_run(&test, &claimed, ending).await;
            let owner = &claimed.account.owner;
            let decision = choose_decision(is_approved);
            let status =
                decide_approval(&test, owner, &approval, decision).await;
            let to_runner = list_approvals(&test, &claimed.holder).await;
            let stored = find_listed(&to_runner, &approval);
            let stored_decision = stored.map(|listed| listed.decision.clone());
            (status, stored_decision)
        });

        prop_assert_eq!(status, StatusCode::CONFLICT);
        prop_assert_eq!(stored_decision, Some(None));
    }

    #[test]
    fn test_record_decision_property_decides_questions_of_running_runs(
        summary in SUMMARY_PATTERN,
        is_approved in any::<bool>(),
    ) {
        let test = TestServer::start();

        let (status, stored_decision) = block_on(async {
            let (claimed, approval) = ask_while_running(&test, &summary).await;
            let owner = &claimed.account.owner;
            let decision = choose_decision(is_approved);
            let status =
                decide_approval(&test, owner, &approval, decision).await;
            let to_runner = list_approvals(&test, &claimed.holder).await;
            let stored = find_listed(&to_runner, &approval);
            let stored_decision = stored
                .and_then(|listed| listed.decision.as_ref())
                .map(|signed| signed.decision);
            (status, stored_decision)
        });

        prop_assert_eq!(status, StatusCode::OK);
        prop_assert_eq!(stored_decision, Some(choose_decision(is_approved)));
    }

    #[test]
    fn test_record_decision_property_a_refusal_holds_on_every_attempt(
        summary in SUMMARY_PATTERN,
        ending in run_ending(),
        attempts in prop::collection::vec(any::<bool>(), 1..4),
    ) {
        let test = TestServer::start();

        let statuses = block_on(async {
            let (claimed, approval) = ask_while_running(&test, &summary).await;
            end_run(&test, &claimed, ending).await;
            let owner = &claimed.account.owner;
            let mut statuses = Vec::new();
            for is_approved in attempts {
                let decision = choose_decision(is_approved);
                let status =
                    decide_approval(&test, owner, &approval, decision).await;
                statuses.push(status);
            }
            statuses
        });

        for status in statuses {
            prop_assert_eq!(status, StatusCode::CONFLICT);
        }
    }
}
