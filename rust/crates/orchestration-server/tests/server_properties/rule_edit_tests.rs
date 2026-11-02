use axum::http::StatusCode;
use orchestration_api::catalog::SaveRuleRequest;
use orchestration_core::library::Rule;
use proptest::prelude::*;
use proptest::sample::Index;

use crate::fixtures::create_account;
use crate::library_fixtures::{
    CHANGED_DETAILS, MOST_ITEMS, list_rules, rule_path, sample_rule, save_rule,
};
use crate::test_client::{TestServer, block_on};

proptest! {
    #![proptest_config(ProptestConfig::with_cases(8))]

    #[test]
    fn test_update_rule_property_keeps_the_switch_and_the_added_time(
        title in "[A-Z][A-Za-z ]{0,30}",
        is_enabled in any::<bool>(),
    ) {
        let test = TestServer::start();
        let original = sample_rule("Keep commits small", is_enabled);
        let (status, stored) = block_on(async {
            let account = create_account(&test).await;
            save_rule(&test, &account, &original).await;
            let changed = Rule {
                title: title.clone(),
                details: CHANGED_DETAILS.to_owned(),
                enabled: !is_enabled,
                added_at: test.now(),
                ..original.clone()
            };
            let request = SaveRuleRequest { rule: changed };
            let path = rule_path(original.id);
            let response = test.put(&account.owner, &path, &request).await;
            (response.status, list_rules(&test, &account).await)
        });

        prop_assert_eq!(status, StatusCode::OK);
        prop_assert_eq!(stored.len(), 1);
        prop_assert_eq!(stored[0].id, original.id);
        prop_assert_eq!(stored[0].enabled, is_enabled);
        prop_assert_eq!(stored[0].added_at, original.added_at);
        prop_assert_eq!(&stored[0].title, &title);
        prop_assert_eq!(&stored[0].details, CHANGED_DETAILS);
    }

    #[test]
    fn test_delete_rule_property_removes_only_that_rule(
        count in 1..MOST_ITEMS,
        position in any::<Index>(),
    ) {
        let test = TestServer::start();
        let rules: Vec<Rule> = (0..count)
            .map(|number| sample_rule(&format!("Rule {number}"), true))
            .collect();
        let deleted = rules[position.index(count)].clone();
        let (status, repeated, stored) = block_on(async {
            let account = create_account(&test).await;
            for rule in &rules {
                save_rule(&test, &account, rule).await;
            }
            let path = rule_path(deleted.id);
            let response = test.delete(&account.owner, &path).await;
            let repeated = test.delete(&account.owner, &path).await;
            let stored = list_rules(&test, &account).await;
            (response.status, repeated.status, stored)
        });

        prop_assert_eq!(status, StatusCode::NO_CONTENT);
        prop_assert_eq!(repeated, StatusCode::NOT_FOUND);
        prop_assert_eq!(stored.len(), count - 1);
        prop_assert!(stored.iter().all(|rule| rule.id != deleted.id));
    }
}
