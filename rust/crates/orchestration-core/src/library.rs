use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::identifiers::{RuleId, RunId, SkillId};
use crate::scope::Scope;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SkillUsage {
    Automatic,
    WhenChosen,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SkillSource {
    BuiltIn,
    Created,
}

#[derive(
    Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize,
)]
#[serde(rename_all = "snake_case")]
pub enum SkillImprovement {
    #[default]
    Never,
    AskMe,
    Auto,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum SkillChangeOrigin {
    PersonEdit,
    ApprovedAgentRun { run_id: RunId },
    AutomaticAgentRun { run_id: RunId },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SkillChange {
    pub origin: SkillChangeOrigin,
    pub saved_at: DateTime<Utc>,
    pub replaced_instructions: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Skill {
    pub id: SkillId,
    pub name: String,
    pub summary: String,
    pub instructions: String,
    pub scope: Scope,
    pub usage: SkillUsage,
    pub source: SkillSource,
    #[serde(default)]
    pub improvement: SkillImprovement,
    #[serde(default)]
    pub history: Vec<SkillChange>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Rule {
    pub id: RuleId,
    pub title: String,
    pub details: String,
    pub scope: Scope,
    pub enabled: bool,
    pub added_at: DateTime<Utc>,
}
