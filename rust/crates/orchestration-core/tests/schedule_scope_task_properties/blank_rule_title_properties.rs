use chrono::DateTime;
use orchestration_core::agents_markdown::render_agents_markdown;
use orchestration_core::identifiers::{ProjectId, RuleId, WorkspaceId};
use orchestration_core::library::Rule;
use orchestration_core::scope::Scope;
use orchestration_core::scope_rules::applies_to;
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::entity_strategies::{
    project_identifier, rule_with_text, workspace_identifier,
};

const WHITESPACE_CHARACTERS: [char; 10] = [
    ' ', '\t', '\n', '\r', '\u{b}', '\u{85}', '\u{a0}', '\u{2003}',
    '\u{2028}', '\u{3000}',
];
const MOST_WHITESPACE: usize = 6;
const MOST_RULES: usize = 6;
const ITEM_PREFIX: &str = "- ";
const EMPTY_ITEM_LINE: &str = "- .";

fn blank_title() -> impl Strategy<Value = String> {
    vec(
        prop::sample::select(&WHITESPACE_CHARACTERS[..]),
        0..=MOST_WHITESPACE,
    )
    .prop_map(|characters| characters.into_iter().collect())
}

fn written_title() -> impl Strategy<Value = String> {
    "[A-Za-z][a-z]{0,6}( [a-z]{1,5}){0,2}[.!?]?"
}

fn any_details() -> impl Strategy<Value = String> {
    "[ a-z\n]{0,20}"
}

fn blank_or_written_rule() -> impl Strategy<Value = Rule> {
    let title = prop_oneof![blank_title(), written_title()];
    rule_with_text(title, any_details())
}

fn has_blank_title(rule: &Rule) -> bool {
    rule.title.trim().is_empty()
}

fn enabled_everywhere(title: String, details: String) -> Rule {
    Rule {
        id: RuleId(Uuid::nil()),
        title,
        details,
        scope: Scope::everywhere(),
        enabled: true,
        added_at: DateTime::UNIX_EPOCH,
    }
}

proptest! {
    #[test]
    fn test_render_agents_markdown_property_skips_rules_with_blank_titles(
        rules in vec(blank_or_written_rule(), 0..MOST_RULES),
        workspace_id in workspace_identifier(),
        project_id in project_identifier(),
    ) {
        let mut titled_rules: Vec<Rule> = Vec::new();
        for rule in &rules {
            if !has_blank_title(rule) {
                titled_rules.push(rule.clone());
            }
        }

        let with_blank_rules =
            render_agents_markdown(&rules, workspace_id, project_id);
        let without_blank_rules =
            render_agents_markdown(&titled_rules, workspace_id, project_id);

        prop_assert_eq!(with_blank_rules, without_blank_rules);
    }

    #[test]
    fn test_render_agents_markdown_property_only_blank_titles_give_no_file(
        titles in vec(blank_title(), 1..MOST_RULES),
        details in vec(any_details(), MOST_RULES),
    ) {
        let mut rules: Vec<Rule> = Vec::new();
        for (title, detail) in titles.into_iter().zip(details) {
            rules.push(enabled_everywhere(title, detail));
        }
        let workspace_id = WorkspaceId(Uuid::nil());
        let project_id = ProjectId(Uuid::nil());

        let markdown =
            render_agents_markdown(&rules, workspace_id, project_id);

        prop_assert_eq!(markdown, "");
    }

    #[test]
    fn test_render_agents_markdown_property_every_item_names_its_rule(
        rules in vec(blank_or_written_rule(), 0..MOST_RULES),
        workspace_id in workspace_identifier(),
        project_id in project_identifier(),
    ) {
        let mut expected_item_count = 0;
        for rule in &rules {
            let applies = applies_to(&rule.scope, workspace_id, project_id);
            if rule.enabled && applies && !has_blank_title(rule) {
                expected_item_count += 1;
            }
        }

        let markdown =
            render_agents_markdown(&rules, workspace_id, project_id);

        let mut item_count = 0;
        for line in markdown.lines() {
            prop_assert_ne!(line, EMPTY_ITEM_LINE);
            if let Some(item_text) = line.strip_prefix(ITEM_PREFIX) {
                let first_character = item_text.chars().next();
                let is_visible = first_character
                    .is_some_and(|character| !character.is_whitespace());
                prop_assert!(is_visible, "{}", line);
                item_count += 1;
            }
        }
        prop_assert_eq!(item_count, expected_item_count);
    }
}
