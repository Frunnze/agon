use crate::identifiers::{ProjectId, WorkspaceId};
use crate::library::Rule;
use crate::scope_rules::applies_to;

const RULES_HEADER: &str = "# Rules\n\n";
const SENTENCE_ENDINGS: [char; 3] = ['.', '!', '?'];

#[must_use]
pub fn render_agents_markdown(
    rules: &[Rule],
    workspace_id: WorkspaceId,
    project_id: ProjectId,
) -> String {
    let rule_sections: Vec<String> = rules
        .iter()
        .filter(|rule| rule.enabled)
        .filter(|rule| applies_to(&rule.scope, workspace_id, project_id))
        .map(render_rule)
        .collect();

    if rule_sections.is_empty() {
        return String::new();
    }

    format!("{RULES_HEADER}{}", rule_sections.concat())
}

fn render_rule(rule: &Rule) -> String {
    let title_words: Vec<&str> = rule.title.split_whitespace().collect();
    let title = title_words.join(" ");
    let title_line = if title.ends_with(SENTENCE_ENDINGS) {
        format!("- {title}")
    } else {
        format!("- {title}.")
    };

    let mut lines = vec![title_line];
    for detail_line in rule.details.lines() {
        let trimmed_line = detail_line.trim();
        if !trimmed_line.is_empty() {
            lines.push(format!("  {trimmed_line}"));
        }
    }

    let mut section = lines.join("\n");
    section.push('\n');
    section
}
