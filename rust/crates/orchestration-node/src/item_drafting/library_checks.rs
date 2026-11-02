use orchestration_core::scope::{ProjectScope, Scope, WorkspaceScope};

use super::draft_checks::CheckedDraft;
use super::drafting_context::DraftingContext;
use super::item_draft::{ItemDraft, RuleDraft, SkillDraft};
use super::problem_sentences::{
    EMPTY_RULE_TITLE, EMPTY_SCOPE, EMPTY_SKILL_INSTRUCTIONS,
    EMPTY_SKILL_SUMMARY, FOREIGN_WORKSPACE, describe_foreign_project,
    describe_taken_skill_name, find_name_problem,
};

pub(super) fn check_skill_draft(
    context: &DraftingContext,
    skill: &SkillDraft,
) -> CheckedDraft {
    let trimmed = skill.trimmed();
    let summary_problem = trimmed
        .summary
        .is_empty()
        .then(|| EMPTY_SKILL_SUMMARY.to_owned());
    let instructions_problem = trimmed
        .instructions
        .is_empty()
        .then(|| EMPTY_SKILL_INSTRUCTIONS.to_owned());
    let possible_problems = [
        find_skill_name_problem(context, &trimmed.name),
        summary_problem,
        instructions_problem,
    ];
    let mut problems: Vec<String> =
        possible_problems.into_iter().flatten().collect();
    problems.extend(find_scope_problems(context, &trimmed.scope));
    CheckedDraft {
        draft: ItemDraft::Skill(trimmed),
        problems,
    }
}

pub(super) fn check_rule_draft(
    context: &DraftingContext,
    rule: &RuleDraft,
) -> CheckedDraft {
    let trimmed = rule.trimmed();
    let mut problems = Vec::new();
    if trimmed.title.is_empty() {
        problems.push(EMPTY_RULE_TITLE.to_owned());
    }
    problems.extend(find_scope_problems(context, &trimmed.scope));
    CheckedDraft {
        draft: ItemDraft::Rule(trimmed),
        problems,
    }
}

fn find_skill_name_problem(
    context: &DraftingContext,
    name: &str,
) -> Option<String> {
    let is_taken = context.skills.iter().any(|skill| skill.name == name);
    find_name_problem(name)
        .or_else(|| is_taken.then(|| describe_taken_skill_name(name)))
}

fn find_scope_problems(
    context: &DraftingContext,
    scope: &Scope,
) -> Vec<String> {
    let possible_problems = [
        find_workspace_scope_problem(context, &scope.workspaces),
        find_project_scope_problem(context, &scope.projects),
    ];
    let mut problems = Vec::new();
    for problem in possible_problems.into_iter().flatten() {
        if !problems.contains(&problem) {
            problems.push(problem);
        }
    }
    problems
}

fn find_workspace_scope_problem(
    context: &DraftingContext,
    workspaces: &WorkspaceScope,
) -> Option<String> {
    let WorkspaceScope::OnlyWorkspaces { workspaces } = workspaces else {
        return None;
    };
    if workspaces.is_empty() {
        return Some(EMPTY_SCOPE.to_owned());
    }
    let has_other_workspace = workspaces
        .iter()
        .any(|workspace_id| *workspace_id != context.workspace.id);
    has_other_workspace.then(|| FOREIGN_WORKSPACE.to_owned())
}

fn find_project_scope_problem(
    context: &DraftingContext,
    projects: &ProjectScope,
) -> Option<String> {
    let ProjectScope::OnlyProjects { projects } = projects else {
        return None;
    };
    if projects.is_empty() {
        return Some(EMPTY_SCOPE.to_owned());
    }
    let has_foreign_project = projects
        .iter()
        .any(|project_id| !context.includes_project(*project_id));
    has_foreign_project
        .then(|| describe_foreign_project(&context.workspace.name))
}
