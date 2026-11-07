use chrono::DateTime;
use orchestration_core::agents_markdown::render_agents_markdown;
use orchestration_core::identifiers::{ProjectId, RuleId, WorkspaceId};
use orchestration_core::library::Rule;
use orchestration_core::rule_titles::{RuleTitleProblem, validate_rule_title};
use orchestration_core::scope::Scope;
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

const WHITESPACE_CHARACTERS: [char; 10] = [
    ' ', '\t', '\n', '\r', '\u{b}', '\u{85}', '\u{a0}', '\u{2003}',
    '\u{2028}', '\u{3000}',
];
const MOST_WHITESPACE: usize = 6;
const RULE_WORD: &str = "rule";

fn whitespace_run() -> impl Strategy<Value = String> {
    vec(
        prop::sample::select(&WHITESPACE_CHARACTERS[..]),
        0..=MOST_WHITESPACE,
    )
    .prop_map(|characters| characters.into_iter().collect())
}

fn visible_character() -> impl Strategy<Value = char> {
    any::<char>().prop_filter("a visible character", |character| {
        !character.is_whitespace()
    })
}

fn any_title() -> impl Strategy<Value = String> {
    prop_oneof![
        whitespace_run(),
        (whitespace_run(), visible_character(), whitespace_run()).prop_map(
            |(before, character, after)| format!("{before}{character}{after}")
        ),
        any::<String>(),
    ]
}

fn render_title_line(title: &str) -> String {
    let rule = Rule {
        id: RuleId(Uuid::nil()),
        title: title.to_owned(),
        details: String::new(),
        scope: Scope::everywhere(),
        enabled: true,
        added_at: DateTime::UNIX_EPOCH,
    };
    let workspace_id = WorkspaceId(Uuid::nil());
    let project_id = ProjectId(Uuid::nil());
    let markdown = render_agents_markdown(&[rule], workspace_id, project_id);
    let title_line = markdown.lines().find(|line| line.starts_with('-'));
    title_line.unwrap_or_default().to_owned()
}

proptest! {
    #[test]
    fn test_validate_rule_title_property_refuses_every_blank_title(
        title in whitespace_run(),
    ) {
        let verdict = validate_rule_title(&title);

        prop_assert_eq!(&verdict, &Err(RuleTitleProblem::Blank));
        let message = verdict.err().map(|problem| problem.to_string());
        prop_assert!(message.unwrap_or_default().contains(RULE_WORD));
    }

    #[test]
    fn test_validate_rule_title_property_accepts_any_visible_character(
        before in whitespace_run(),
        character in visible_character(),
        after in whitespace_run(),
    ) {
        let title = format!("{before}{character}{after}");

        prop_assert_eq!(validate_rule_title(&title), Ok(()));
    }

    #[test]
    fn test_validate_rule_title_property_accepted_titles_render_a_word(
        title in any_title(),
    ) {
        let first_word = title.split_whitespace().next();
        let title_line = render_title_line(&title);

        match validate_rule_title(&title) {
            Ok(()) => {
                let word = first_word.unwrap_or_default();
                prop_assert!(!word.is_empty());
                let starts_with_word =
                    title_line.starts_with(&format!("- {word}"));
                prop_assert!(starts_with_word, "{}", title_line);
            }
            Err(RuleTitleProblem::Blank) => {
                prop_assert_eq!(first_word, None);
            }
        }
    }
}
