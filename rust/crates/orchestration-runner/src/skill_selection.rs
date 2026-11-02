use orchestration_core::identifiers::{ProjectId, WorkspaceId};
use orchestration_core::library::{Skill, SkillUsage};
use orchestration_core::scope_rules::applies_to;

use crate::step_plan::StepPlan;

#[must_use]
pub fn select_step_skills<'skills>(
    step: &StepPlan,
    skills: &'skills [Skill],
    workspace_id: WorkspaceId,
    project_id: ProjectId,
) -> Vec<&'skills Skill> {
    let mut selected = Vec::new();
    for skill in skills {
        let is_pinned = step.pinned_skills.contains(&skill.id);
        let is_offered_automatically = step.uses_automatic_skills
            && skill.usage == SkillUsage::Automatic
            && applies_to(&skill.scope, workspace_id, project_id);
        if is_pinned || is_offered_automatically {
            selected.push(skill);
        }
    }
    selected
}
