use serde::Serialize;

use super::drafting_context::DraftingContext;
use super::item_draft::ItemDraft;
use super::library_checks::{check_rule_draft, check_skill_draft};
use super::project_checks::check_project_draft;
use super::work_checks::{check_job_draft, check_task_draft};

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct CheckedDraft {
    pub draft: ItemDraft,
    pub problems: Vec<String>,
}

#[must_use]
pub fn check_item_draft(
    context: &DraftingContext,
    drafted: &ItemDraft,
) -> CheckedDraft {
    match drafted {
        ItemDraft::Task(work) => check_task_draft(context, work),
        ItemDraft::Job(work) => check_job_draft(context, work),
        ItemDraft::Project(project) => check_project_draft(context, project),
        ItemDraft::Skill(skill) => check_skill_draft(context, skill),
        ItemDraft::Rule(rule) => check_rule_draft(context, rule),
    }
}
