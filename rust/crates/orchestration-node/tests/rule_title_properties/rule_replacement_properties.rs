use proptest::collection::vec;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::json;

use crate::rule_title_strategies::{
    RULE_WORD, blank_or_worded_title, blank_title, worded_title,
};
use crate::rule_workspace::{
    TITLE_CASES, create_rule, list_rule_titles, prepared_or_panic, update_rule,
};
use crate::test_device::fail;

const KEPT_TITLE: &str = "Keep commits small";
const MOST_UPDATES: usize = 4;

#[test]
fn test_replace_rule_property_refuses_blank_titles() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(TITLE_CASES));
    let Ok(created) = create_rule(&prepared, KEPT_TITLE) else {
        panic!("the rule is created");
    };

    let outcome = runner.run(&blank_title(), |title| {
        let refusal = update_rule(&prepared, &created["id"], &title);
        let titles = list_rule_titles(&prepared).map_err(fail)?;

        let message = refusal.err().unwrap_or_default();
        prop_assert!(message.contains(RULE_WORD), "{}", message);
        prop_assert_eq!(titles, vec![json!(KEPT_TITLE)]);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_replace_rule_property_keeps_worded_titles_exactly() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(TITLE_CASES));
    let Ok(created) = create_rule(&prepared, KEPT_TITLE) else {
        panic!("the rule is created");
    };

    let outcome = runner.run(&worded_title(), |title| {
        let updated =
            update_rule(&prepared, &created["id"], &title).map_err(fail)?;
        let titles = list_rule_titles(&prepared).map_err(fail)?;

        prop_assert_eq!(&updated["title"], &json!(title));
        prop_assert_eq!(titles, vec![json!(title)]);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_replace_rule_property_keeps_the_last_worded_title() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(TITLE_CASES));
    let titles_strategy = vec(blank_or_worded_title(), 1..=MOST_UPDATES);
    let Ok(created) = create_rule(&prepared, KEPT_TITLE) else {
        panic!("the rule is created");
    };

    let outcome = runner.run(&titles_strategy, |titles| {
        let starting_titles = list_rule_titles(&prepared).map_err(fail)?;
        let mut expected_title = starting_titles[0].clone();
        for title in &titles {
            let updated = update_rule(&prepared, &created["id"], title);
            if updated.is_ok() {
                expected_title = json!(title);
            }
            prop_assert_eq!(updated.is_ok(), !title.trim().is_empty());
        }
        let stored_titles = list_rule_titles(&prepared).map_err(fail)?;

        prop_assert_eq!(stored_titles, vec![expected_title]);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
