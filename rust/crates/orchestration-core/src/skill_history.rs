use chrono::{DateTime, Utc};
use thiserror::Error;

use crate::library::{Skill, SkillChange, SkillChangeOrigin};

pub const KEPT_SKILL_CHANGES: usize = 20;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Error)]
pub enum SkillUndoProblem {
    #[error("the skill's latest change was not made by an agent")]
    NoAgentChange,
}

#[must_use]
pub fn record_skill_change(
    skill: &Skill,
    new_instructions: &str,
    origin: SkillChangeOrigin,
    saved_at: DateTime<Utc>,
) -> Skill {
    let change = SkillChange {
        origin,
        saved_at,
        replaced_instructions: skill.instructions.clone(),
    };
    let mut history = skill.history.clone();
    history.push(change);
    let excess = history.len().saturating_sub(KEPT_SKILL_CHANGES);
    history.drain(..excess);

    Skill {
        instructions: new_instructions.to_owned(),
        history,
        ..skill.clone()
    }
}

pub fn undo_latest_agent_change(
    skill: &Skill,
) -> Result<Skill, SkillUndoProblem> {
    let mut history = skill.history.clone();
    let Some(latest_change) = history.pop() else {
        return Err(SkillUndoProblem::NoAgentChange);
    };
    if latest_change.origin == SkillChangeOrigin::PersonEdit {
        return Err(SkillUndoProblem::NoAgentChange);
    }

    Ok(Skill {
        instructions: latest_change.replaced_instructions,
        history,
        ..skill.clone()
    })
}
