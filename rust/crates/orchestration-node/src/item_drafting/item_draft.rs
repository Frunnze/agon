use orchestration_core::agent_place::AgentPlace;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{ProjectId, SkillId};
use orchestration_core::library::SkillUsage;
use orchestration_core::scope::Scope;
use orchestration_core::task::{Schedule, TaskDoer};
use orchestration_core::workspace::AgentAccess;
use serde::{Deserialize, Serialize};

use super::answer_defaults::{
    pick_form_agent_access, pick_form_agent_place, pick_form_approval_policy,
    pick_form_automatic_skills_choice, pick_form_doer,
    pick_form_runner_target,
};

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ItemDraft {
    Task(WorkDraft),
    Job(WorkDraft),
    Project(ProjectDraft),
    Skill(SkillDraft),
    Rule(RuleDraft),
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct WorkDraft {
    pub title: String,
    #[serde(default)]
    pub details: String,
    pub project_id: Option<ProjectId>,
    #[serde(default = "pick_form_doer")]
    pub doer: TaskDoer,
    #[serde(default = "pick_form_runner_target")]
    pub runs_on: RunnerTarget,
    #[serde(default = "pick_form_agent_place")]
    pub agent_place: AgentPlace,
    #[serde(default)]
    pub skills: Vec<SkillId>,
    #[serde(default = "pick_form_automatic_skills_choice")]
    pub uses_automatic_skills: bool,
    #[serde(default = "pick_form_approval_policy")]
    pub approval_policy: ApprovalPolicy,
    pub schedule: Option<Schedule>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProjectDraft {
    #[serde(default)]
    pub name: String,
    pub repositories: Vec<RepositoryDraft>,
    #[serde(default = "pick_form_agent_access")]
    pub agent_access: AgentAccess,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RepositoryDraft {
    pub address: String,
    pub default_branch: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SkillDraft {
    pub name: String,
    pub summary: String,
    pub instructions: String,
    pub scope: Scope,
    pub usage: SkillUsage,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RuleDraft {
    pub title: String,
    #[serde(default)]
    pub details: String,
    pub scope: Scope,
}

impl WorkDraft {
    pub(super) fn trimmed(&self) -> Self {
        Self {
            title: self.title.trim().to_owned(),
            details: self.details.trim().to_owned(),
            ..self.clone()
        }
    }
}

impl SkillDraft {
    pub(super) fn trimmed(&self) -> Self {
        Self {
            name: self.name.trim().to_owned(),
            summary: self.summary.trim().to_owned(),
            instructions: self.instructions.trim().to_owned(),
            ..self.clone()
        }
    }
}

impl RuleDraft {
    pub(super) fn trimmed(&self) -> Self {
        Self {
            title: self.title.trim().to_owned(),
            details: self.details.trim().to_owned(),
            ..self.clone()
        }
    }
}
