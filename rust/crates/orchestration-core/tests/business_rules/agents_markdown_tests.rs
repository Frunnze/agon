use chrono::DateTime;
use orchestration_core::agents_markdown::render_agents_markdown;
use orchestration_core::identifiers::{ProjectId, RuleId, WorkspaceId};
use orchestration_core::library::Rule;
use orchestration_core::scope::{ProjectScope, Scope, WorkspaceScope};
use orchestration_core::scope_rules::applies_to;
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::entity_strategies::{
    project_identifier, rule_with_text, workspace_identifier,
};

const MAXIMUM_RULES: usize = 6;
const MAXIMUM_DETAIL_LINES: usize = 3;
const HEADER: &str = "# Rules";

fn design_rule(
    number: u128,
    title: &str,
    details: &str,
    scope: Scope,
    enabled: bool,
) -> Rule {
    Rule {
        id: RuleId(Uuid::from_u128(number)),
        title: title.to_owned(),
        details: details.to_owned(),
        scope,
        enabled,
        added_at: DateTime::UNIX_EPOCH,
    }
}

fn single_line_title() -> impl Strategy<Value = String> {
    "[A-Z][a-z]{0,8}( [a-z]{1,6}){0,3}[.!?]?"
}

fn multi_line_details() -> impl Strategy<Value = String> {
    vec(
        " ?[A-Za-z]{0,6}( [a-z]{1,5}){0,2} ?",
        0..MAXIMUM_DETAIL_LINES,
    )
    .prop_map(|lines| lines.join("\n"))
}

fn expected_rule_lines(rule: &Rule) -> Vec<String> {
    let has_sentence_ending = rule.title.ends_with(['.', '!', '?']);
    let title_line = if has_sentence_ending {
        format!("- {}", rule.title)
    } else {
        format!("- {}.", rule.title)
    };
    let mut lines = vec![title_line];
    for detail_line in rule.details.lines() {
        let trimmed_line = detail_line.trim();
        if !trimmed_line.is_empty() {
            lines.push(format!("  {trimmed_line}"));
        }
    }
    lines
}

#[test]
fn test_render_agents_markdown_matches_design_preview_for_acme_app() {
    let acme = WorkspaceId(Uuid::from_u128(1));
    let acme_app = ProjectId(Uuid::from_u128(2));
    let acme_projects_only = Scope {
        workspaces: WorkspaceScope::OnlyWorkspaces {
            workspaces: vec![acme],
        },
        projects: ProjectScope::AllProjects,
    };
    let acme_app_only = Scope {
        workspaces: WorkspaceScope::OnlyWorkspaces {
            workspaces: vec![acme],
        },
        projects: ProjectScope::OnlyProjects {
            projects: vec![acme_app],
        },
    };
    let rules = vec![
        design_rule(
            1,
            "Never push to main",
            "Open a pull request instead.",
            Scope::everywhere(),
            true,
        ),
        design_rule(
            2,
            "Test before changing code",
            "Write a failing test first, then make it pass.",
            Scope::everywhere(),
            true,
        ),
        design_rule(
            3,
            "Follow the app style guide",
            "For any text a customer will read.",
            acme_app_only,
            true,
        ),
        design_rule(
            4,
            "Ask before adding a dependency",
            "Explain why it is needed.",
            acme_projects_only,
            false,
        ),
    ];

    let markdown = render_agents_markdown(&rules, acme, acme_app);

    let expected = "# Rules\n\n\
        - Never push to main.\n  Open a pull request instead.\n\
        - Test before changing code.\n  \
        Write a failing test first, then make it pass.\n\
        - Follow the app style guide.\n  \
        For any text a customer will read.\n";
    assert_eq!(markdown, expected);
}

proptest! {
    #[test]
    fn test_render_agents_markdown_property_lists_enabled_applying_rules(
        rules in vec(
            rule_with_text(single_line_title(), multi_line_details()),
            0..MAXIMUM_RULES,
        ),
        workspace_id in workspace_identifier(),
        project_id in project_identifier(),
    ) {
        let mut expected_body: Vec<String> = Vec::new();
        for rule in &rules {
            let applies = applies_to(&rule.scope, workspace_id, project_id);
            if rule.enabled && applies {
                expected_body.extend(expected_rule_lines(rule));
            }
        }

        let markdown =
            render_agents_markdown(&rules, workspace_id, project_id);

        let rendered_lines: Vec<&str> = markdown.lines().collect();
        if expected_body.is_empty() {
            prop_assert_eq!(markdown.as_str(), "");
        } else {
            prop_assert_eq!(rendered_lines[0], HEADER);
            prop_assert_eq!(rendered_lines[1], "");
            prop_assert_eq!(rendered_lines[2..].to_vec(), expected_body);
            prop_assert!(markdown.ends_with('\n'));
        }
    }

    #[test]
    fn test_render_agents_markdown_property_disabled_rules_render_nothing(
        rules in vec(
            rule_with_text(single_line_title(), multi_line_details()),
            0..MAXIMUM_RULES,
        ),
        workspace_id in workspace_identifier(),
        project_id in project_identifier(),
    ) {
        let disabled_rules: Vec<Rule> = rules
            .into_iter()
            .map(|rule| Rule { enabled: false, ..rule })
            .collect();

        let markdown =
            render_agents_markdown(&disabled_rules, workspace_id, project_id);

        prop_assert_eq!(markdown, "");
    }

    #[test]
    fn test_render_agents_markdown_fuzz_lines_keep_list_structure(
        rules in vec(
            rule_with_text(any::<String>(), any::<String>()),
            0..MAXIMUM_RULES,
        ),
        workspace_id in workspace_identifier(),
        project_id in project_identifier(),
    ) {
        let markdown =
            render_agents_markdown(&rules, workspace_id, project_id);

        let included_count = rules
            .iter()
            .filter(|rule| {
                rule.enabled
                    && applies_to(&rule.scope, workspace_id, project_id)
            })
            .count();
        let rendered_lines: Vec<&str> = markdown.lines().collect();
        let item_count = rendered_lines
            .iter()
            .filter(|line| line.starts_with("- "))
            .count();
        if included_count == 0 {
            prop_assert_eq!(markdown.as_str(), "");
        } else {
            prop_assert_eq!(rendered_lines[0], HEADER);
            prop_assert_eq!(rendered_lines[1], "");
            for line in &rendered_lines[2..] {
                prop_assert!(line.starts_with("- ") || line.starts_with("  "));
            }
            prop_assert_eq!(item_count, included_count);
        }
    }
}
