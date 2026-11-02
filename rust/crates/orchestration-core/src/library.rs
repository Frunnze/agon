use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::identifiers::{RuleId, SkillId};
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

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Skill {
    pub id: SkillId,
    pub name: String,
    pub summary: String,
    pub instructions: String,
    pub scope: Scope,
    pub usage: SkillUsage,
    pub source: SkillSource,
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
