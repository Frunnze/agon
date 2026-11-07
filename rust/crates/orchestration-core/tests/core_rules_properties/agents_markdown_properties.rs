use chrono::DateTime;
use orchestration_core::agents_markdown::render_agents_markdown;
use orchestration_core::identifiers::{ProjectId, RuleId, WorkspaceId};
use orchestration_core::library::Rule;
use orchestration_core::scope::Scope;
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::entity_strategies::{
    project_identifier, rule_with_text, workspace_identifier,
};

const MAXIMUM_RULES: usize = 5;
const HEADER: &str = "# Rules\n\n";
const ITEM_PREFIX: &str = "- ";
const DETAIL_INDENT: &str = "  ";
const SENTENCE_ENDINGS: [char; 3] = ['.', '!', '?'];

fn plain_title() -> impl Strategy<Value = String> {
    "[A-Za-z][a-z]{0,6}( [a-z]{1,5}){0,3}[.!?]?"
}

fn whitespace_run() -> impl Strategy<Value = String> {
    "[ \t\n\r]{1,3}"
}

fn any_detail_text() -> impl Strategy<Value = String> {
    vec("[ \t]{0,2}[a-z]{0,5}( [a-z]{1,4}){0,2}[ \t]{0,2}", 0..4)
        .prop_map(|lines| lines.join("\n"))
}

fn rule_everywhere(title: String, details: String) -> Rule {
    Rule {
        id: RuleId(Uuid::nil()),
        title,
        details,
        scope: Scope::everywhere(),
        enabled: true,
        added_at: DateTime::UNIX_EPOCH,
    }
}

fn render_one(rule: Rule) -> String {
    let workspace_id = WorkspaceId(Uuid::nil());
    let project_id = ProjectId(Uuid::nil());
    render_agents_markdown(&[rule], workspace_id, project_id)
}

fn remove_header(markdown: &str) -> &str {
    markdown.strip_prefix(HEADER).unwrap_or(markdown)
}

proptest! {
    #[test]
    fn test_render_agents_markdown_property_joins_lists_section_by_section(
        first_rules in vec(rule_with_text(plain_title(), any_detail_text()),
            0..MAXIMUM_RULES),
        second_rules in vec(rule_with_text(plain_title(), any_detail_text()),
            0..MAXIMUM_RULES),
        workspace_id in workspace_identifier(),
        project_id in project_identifier(),
    ) {
        let mut all_rules = first_rules.clone();
        all_rules.extend(second_rules.iter().cloned());

        let first = render_agents_markdown(
            &first_rules, workspace_id, project_id,
        );
        let second = render_agents_markdown(
            &second_rules, workspace_id, project_id,
        );
        let joined = render_agents_markdown(
            &all_rules, workspace_id, project_id,
        );

        let joined_body =
            format!("{}{}", remove_header(&first), remove_header(&second));
        prop_assert_eq!(remove_header(&joined), joined_body.as_str());
        prop_assert_eq!(joined.is_empty(), joined_body.is_empty());
    }

    #[test]
    fn test_render_rule_property_collapses_whitespace_in_the_title(
        words in vec("[A-Za-z]{1,6}[.!?]?", 1..5),
        gaps in vec(whitespace_run(), 5),
        details in any_detail_text(),
    ) {
        let single_spaced_title = words.join(" ");
        let mut spaced_title = gaps[0].clone();
        for (word, gap) in words.iter().zip(&gaps[1..]) {
            spaced_title.push_str(word);
            spaced_title.push_str(gap);
        }

        let from_spaced = render_one(rule_everywhere(
            spaced_title, details.clone(),
        ));
        let from_single = render_one(rule_everywhere(
            single_spaced_title, details,
        ));

        prop_assert_eq!(from_spaced, from_single);
    }

    #[test]
    fn test_render_rule_property_ends_the_title_with_one_sentence_ending(
        title in plain_title(),
        details in any_detail_text(),
    ) {
        let markdown = render_one(rule_everywhere(title.clone(), details));

        let title_line = remove_header(&markdown).lines().next();
        let title_text = title_line
            .and_then(|line| line.strip_prefix(ITEM_PREFIX))
            .ok_or_else(|| TestCaseError::fail("the rule has no item line"))?;

        prop_assert!(title_text.ends_with(SENTENCE_ENDINGS));
        prop_assert!(title_text.starts_with(&title));
        prop_assert!(title_text.len() <= title.len() + 1);
    }

    #[test]
    fn test_render_rule_property_indents_each_written_detail_line(
        title in plain_title(),
        details in any_detail_text(),
    ) {
        let markdown = render_one(rule_everywhere(title, details.clone()));

        let rendered_details: Vec<String> = remove_header(&markdown)
            .lines()
            .skip(1)
            .map(str::to_owned)
            .collect();
        let mut expected_details = Vec::new();
        for detail_line in details.lines() {
            let written = detail_line.trim();
            if !written.is_empty() {
                expected_details.push(format!("{DETAIL_INDENT}{written}"));
            }
        }
        prop_assert_eq!(rendered_details, expected_details);
        prop_assert!(markdown.ends_with('\n'));
    }
}
