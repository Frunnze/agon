use std::collections::BTreeSet;

use chrono::DateTime;
use orchestration_core::agents_markdown::render_agents_markdown;
use orchestration_core::identifiers::{ProjectId, RuleId, WorkspaceId};
use orchestration_core::library::Rule;
use orchestration_core::rule_titles::validate_rule_title;
use orchestration_core::scope::Scope;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::Index;
use serde::Deserialize;
use uuid::Uuid;

const SHARED_WHITE_SPACE_TABLE: &str =
    include_str!("../fixtures/rule_title_white_space_cases.json");
const MOST_PADDING: usize = 4;

#[derive(Debug, Deserialize)]
struct SharedWhiteSpaceTable {
    white_space: String,
    cases: Vec<SharedWhiteSpaceCase>,
}

#[derive(Debug, Deserialize)]
struct SharedWhiteSpaceCase {
    title: String,
    details: String,
    is_blank: bool,
    collapsed: String,
    markdown: String,
}

fn read_shared_table() -> Result<SharedWhiteSpaceTable, serde_json::Error> {
    serde_json::from_str(SHARED_WHITE_SPACE_TABLE)
}

fn render_one(title: &str, details: &str) -> String {
    let rule = Rule {
        id: RuleId(Uuid::nil()),
        title: title.to_owned(),
        details: details.to_owned(),
        scope: Scope::everywhere(),
        enabled: true,
        added_at: DateTime::UNIX_EPOCH,
    };
    let workspace_id = WorkspaceId(Uuid::nil());
    let project_id = ProjectId(Uuid::nil());
    render_agents_markdown(&[rule], workspace_id, project_id)
}

fn pick_padding(white_space: &[char], positions: &[Index]) -> String {
    let mut padding = String::new();
    for position in positions {
        padding.push(white_space[position.index(white_space.len())]);
    }
    padding
}

#[test]
fn test_validate_rule_title_property_shared_space_is_unicode_white_space()
-> Result<(), serde_json::Error> {
    let table = read_shared_table()?;
    let shared: BTreeSet<char> = table.white_space.chars().collect();
    let unicode_white_space: BTreeSet<char> = (0..=u32::from(char::MAX))
        .filter_map(char::from_u32)
        .filter(|character| character.is_whitespace())
        .collect();

    assert_eq!(shared, unicode_white_space);
    for character in shared {
        assert!(validate_rule_title(&character.to_string()).is_err());
    }
    Ok(())
}

#[test]
fn test_validate_rule_title_property_agrees_with_the_shared_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_table()?.cases {
        let is_blank = validate_rule_title(&case.title).is_err();

        assert_eq!(is_blank, case.is_blank, "{:?}", case.title);
    }
    Ok(())
}

#[test]
fn test_render_agents_markdown_property_agrees_with_the_shared_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_table()?.cases {
        let markdown = render_one(&case.title, &case.details);

        assert_eq!(markdown, case.markdown, "{:?}", case.title);
    }
    Ok(())
}

#[test]
fn test_render_agents_markdown_property_shows_the_shared_collapsed_title()
-> Result<(), serde_json::Error> {
    for case in read_shared_table()?.cases {
        let title_words: Vec<&str> = case.title.split_whitespace().collect();
        let markdown = render_one(&case.title, &case.details);
        let expected_start = format!("# Rules\n\n- {}", case.collapsed);

        assert_eq!(title_words.join(" "), case.collapsed, "{:?}", case.title);
        assert_eq!(case.is_blank, case.collapsed.is_empty());
        if !case.is_blank {
            assert!(markdown.starts_with(&expected_start), "{markdown:?}");
        }
    }
    Ok(())
}

proptest! {
    #[test]
    fn test_render_agents_markdown_property_shared_titles_ignore_padding(
        case_position in any::<Index>(),
        leading_positions in vec(any::<Index>(), 0..=MOST_PADDING),
        trailing_positions in vec(any::<Index>(), 0..=MOST_PADDING),
    ) {
        let table = read_shared_table()?;
        let white_space: Vec<char> = table.white_space.chars().collect();
        let case = &table.cases[case_position.index(table.cases.len())];
        let leading = pick_padding(&white_space, &leading_positions);
        let trailing = pick_padding(&white_space, &trailing_positions);
        let padded = format!("{leading}{}{trailing}", case.title);

        let is_blank = validate_rule_title(&padded).is_err();
        let markdown = render_one(&padded, &case.details);

        prop_assert_eq!(is_blank, case.is_blank);
        prop_assert_eq!(markdown, case.markdown.clone());
    }
}
