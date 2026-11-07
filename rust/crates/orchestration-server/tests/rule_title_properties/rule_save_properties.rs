use axum::http::StatusCode;
use orchestration_api::catalog::SaveRuleRequest;
use orchestration_core::library::Rule;
use proptest::prelude::*;

use crate::fixtures::create_account;
use crate::library_fixtures::{list_rules, sample_rule, save_rule};
use crate::rule_title_strategies::{RULE_WORD, blank_title, worded_title};
use crate::test_client::{TestServer, block_on};

const RULES_PATH: &str = "/rules";
const KEPT_TITLE: &str = "Keep commits small";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(8))]

    #[test]
    fn test_save_rule_property_refuses_blank_titles(title in blank_title()) {
        let test = TestServer::start();
        let blank_rule = sample_rule(&title, true);
        let (status, message, stored) = block_on(async {
            let account = create_account(&test).await;
            let request = SaveRuleRequest { rule: blank_rule };
            let response =
                test.post(&account.owner, RULES_PATH, &request).await;
            let message = response.error_message();
            (response.status, message, list_rules(&test, &account).await)
        });

        prop_assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        prop_assert!(message.contains(RULE_WORD), "{}", message);
        prop_assert!(stored.is_empty());
    }

    #[test]
    fn test_save_rule_property_keeps_worded_titles_exactly(
        title in worded_title(),
    ) {
        let test = TestServer::start();
        let worded_rule = sample_rule(&title, true);
        let stored: Vec<Rule> = block_on(async {
            let account = create_account(&test).await;
            save_rule(&test, &account, &worded_rule).await;
            list_rules(&test, &account).await
        });

        prop_assert_eq!(stored, vec![worded_rule]);
    }

    #[test]
    fn test_save_rule_property_blank_title_keeps_the_earlier_rule(
        title in blank_title(),
    ) {
        let test = TestServer::start();
        let kept_rule = sample_rule(KEPT_TITLE, true);
        let blank_rule = Rule {
            title,
            ..kept_rule.clone()
        };
        let (status, stored) = block_on(async {
            let account = create_account(&test).await;
            save_rule(&test, &account, &kept_rule).await;
            let request = SaveRuleRequest { rule: blank_rule };
            let response =
                test.post(&account.owner, RULES_PATH, &request).await;
            (response.status, list_rules(&test, &account).await)
        });

        prop_assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        prop_assert_eq!(stored, vec![kept_rule]);
    }
}
