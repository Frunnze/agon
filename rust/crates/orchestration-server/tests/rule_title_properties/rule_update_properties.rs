use axum::http::StatusCode;
use orchestration_api::catalog::SaveRuleRequest;
use orchestration_core::library::Rule;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::fixtures::create_account;
use crate::library_fixtures::{list_rules, rule_path, sample_rule, save_rule};
use crate::rule_title_strategies::{
    RULE_WORD, blank_or_worded_title, blank_title, worded_title,
};
use crate::test_client::{TestServer, block_on};

const KEPT_TITLE: &str = "Keep commits small";
const MOST_UPDATES: usize = 5;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(8))]

    #[test]
    fn test_update_rule_property_refuses_blank_titles(
        title in blank_title(),
    ) {
        let test = TestServer::start();
        let kept_rule = sample_rule(KEPT_TITLE, true);
        let blank_rule = Rule {
            title,
            ..kept_rule.clone()
        };
        let (status, message, stored) = block_on(async {
            let account = create_account(&test).await;
            save_rule(&test, &account, &kept_rule).await;
            let request = SaveRuleRequest { rule: blank_rule };
            let path = rule_path(kept_rule.id);
            let response = test.put(&account.owner, &path, &request).await;
            let message = response.error_message();
            (response.status, message, list_rules(&test, &account).await)
        });

        prop_assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        prop_assert!(message.contains(RULE_WORD), "{}", message);
        prop_assert_eq!(stored, vec![kept_rule]);
    }

    #[test]
    fn test_update_rule_property_keeps_worded_titles_exactly(
        title in worded_title(),
    ) {
        let test = TestServer::start();
        let original_rule = sample_rule(KEPT_TITLE, true);
        let worded_rule = Rule {
            title: title.clone(),
            ..original_rule.clone()
        };
        let (status, stored) = block_on(async {
            let account = create_account(&test).await;
            save_rule(&test, &account, &original_rule).await;
            let request = SaveRuleRequest { rule: worded_rule };
            let path = rule_path(original_rule.id);
            let response = test.put(&account.owner, &path, &request).await;
            (response.status, list_rules(&test, &account).await)
        });

        prop_assert_eq!(status, StatusCode::OK);
        prop_assert_eq!(stored.len(), 1);
        prop_assert_eq!(&stored[0].title, &title);
    }

    #[test]
    fn test_update_rule_property_keeps_the_last_worded_title(
        titles in vec(blank_or_worded_title(), 1..=MOST_UPDATES),
    ) {
        let test = TestServer::start();
        let original_rule = sample_rule(KEPT_TITLE, true);
        let mut expected_title = KEPT_TITLE.to_owned();
        for title in &titles {
            if !title.trim().is_empty() {
                expected_title.clone_from(title);
            }
        }
        let stored = block_on(async {
            let account = create_account(&test).await;
            save_rule(&test, &account, &original_rule).await;
            let path = rule_path(original_rule.id);
            for title in &titles {
                let changed_rule = Rule {
                    title: title.clone(),
                    ..original_rule.clone()
                };
                let request = SaveRuleRequest { rule: changed_rule };
                test.put(&account.owner, &path, &request).await;
            }
            list_rules(&test, &account).await
        });

        prop_assert_eq!(stored.len(), 1);
        prop_assert_eq!(&stored[0].title, &expected_title);
    }
}
