use orchestration_core::agent_place::AgentPlace;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{ProjectId, SkillId};
use orchestration_core::library::SkillUsage;
use orchestration_core::scope::Scope;
use orchestration_core::task::{Schedule, TaskDoer};
use orchestration_core::workspace::AgentAccess;
use serde::{Deserialize, Serialize};

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
    pub details: String,
    pub project_id: Option<ProjectId>,
    pub doer: TaskDoer,
    pub runs_on: RunnerTarget,
    pub agent_place: AgentPlace,
    pub skills: Vec<SkillId>,
    pub uses_automatic_skills: bool,
    pub approval_policy: ApprovalPolicy,
    pub schedule: Option<Schedule>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProjectDraft {
    pub name: String,
    pub repositories: Vec<RepositoryDraft>,
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
