use orchestration_node::item_drafting::{DraftKind, DraftingContext};
use serde_json::{Value, json};

fn this_workspace_scope(context: &DraftingContext) -> Value {
    json!({
        "workspaces": {
            "kind": "only_workspaces",
            "workspaces": [context.workspace.id],
        },
        "projects": {"kind": "all_projects"},
    })
}

pub fn well_formed_work(context: &DraftingContext, words: &str) -> Value {
    let first_project_id = context.projects.first().map(|project| project.id);
    let first_skill_ids: Vec<_> = context
        .skills
        .iter()
        .take(1)
        .map(|skill| skill.id)
        .collect();
    let monday_morning = json!({"hour": 9, "minute": 0});
    json!({
        "title": words,
        "details": words,
        "project_id": first_project_id,
        "doer": {"kind": "one_agent", "agent": "codex"},
        "runs_on": {"kind": "runner_with_labels", "labels": ["mac"]},
        "agent_place": "container",
        "skills": first_skill_ids,
        "uses_automatic_skills": false,
        "approval_policy": "never_ask",
        "schedule": {"every": "week", "on": "Mon", "at": monday_morning},
    })
}

pub fn well_formed_answer(
    kind: DraftKind,
    context: &DraftingContext,
    words: &str,
) -> Value {
    match kind {
        DraftKind::Task | DraftKind::Job => well_formed_work(context, words),
        DraftKind::Project => json!({
            "name": "mobile-app",
            "repositories": [{
                "address": "https://github.com/acme/mobile-app",
                "default_branch": "main",
            }],
            "agent_access": "read_only",
        }),
        DraftKind::Skill => json!({
            "name": "changelog-entries",
            "summary": words,
            "instructions": words,
            "scope": this_workspace_scope(context),
            "usage": "when_chosen",
        }),
        DraftKind::Rule => json!({
            "title": words,
            "details": "",
            "scope": this_workspace_scope(context),
        }),
    }
}
