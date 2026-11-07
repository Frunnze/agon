use proptest::collection::vec;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::json;

use crate::rule_title_strategies::{
    RULE_WORD, blank_or_worded_title, blank_title, worded_title,
};
use crate::rule_workspace::{
    TITLE_CASES, create_rule, list_agents_markdown_rule_lines,
    list_rule_titles, prepared_or_panic,
};
use crate::test_device::fail;

const MOST_RULES: usize = 4;

#[test]
fn test_create_rule_property_refuses_blank_titles() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(TITLE_CASES));

    let outcome = runner.run(&blank_title(), |title| {
        let refusal = create_rule(&prepared, &title);
        let titles = list_rule_titles(&prepared).map_err(fail)?;

        let message = refusal.err().unwrap_or_default();
        prop_assert!(message.contains(RULE_WORD), "{}", message);
        prop_assert!(titles.is_empty(), "{:?}", titles);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_create_rule_property_keeps_worded_titles_exactly() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(TITLE_CASES));

    let outcome = runner.run(&worded_title(), |title| {
        let created = create_rule(&prepared, &title).map_err(fail)?;
        let titles = list_rule_titles(&prepared).map_err(fail)?;

        prop_assert_eq!(&created["title"], &json!(title));
        prop_assert!(titles.contains(&json!(title)), "{:?}", titles);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_create_rule_property_agents_markdown_lists_only_worded_rules() {
    let mut runner = TestRunner::new(Config::with_cases(TITLE_CASES));
    let titles_strategy = vec(blank_or_worded_title(), 1..=MOST_RULES);

    let outcome = runner.run(&titles_strategy, |titles| {
        let prepared = prepared_or_panic();
        let mut worded_count = 0;
        for title in &titles {
            let created = create_rule(&prepared, title);
            if created.is_ok() {
                worded_count += 1;
            }
            prop_assert_eq!(created.is_ok(), !title.trim().is_empty());
        }
        let rule_lines =
            list_agents_markdown_rule_lines(&prepared).map_err(fail)?;

        prop_assert_eq!(rule_lines.len(), worded_count);
        for line in &rule_lines {
            let has_letter = line.chars().any(char::is_alphabetic);
            prop_assert!(has_letter, "{}", line);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
