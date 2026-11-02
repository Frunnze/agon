use serde::Deserialize;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DraftKind {
    Task,
    Job,
    Project,
    Skill,
    Rule,
}

impl DraftKind {
    pub(crate) fn name(self) -> &'static str {
        match self {
            Self::Task => "task",
            Self::Job => "job",
            Self::Project => "project",
            Self::Skill => "skill",
            Self::Rule => "rule",
        }
    }

    pub(super) fn explanation(self) -> &'static str {
        match self {
            Self::Task => {
                "A task is one piece of work that one agent or a workflow \
                 does in a project. If the person wants it to repeat, give \
                 it a schedule."
            }
            Self::Job => "A job is a task that repeats on a schedule.",
            Self::Project => {
                "A project names the repos agents work on: GitHub addresses \
                 or git folders on this computer."
            }
            Self::Skill => {
                "A skill is instructions agents can use: automatically when \
                 the work fits, or only when a task, job or workflow agent \
                 chooses it."
            }
            Self::Rule => {
                "A rule is something every agent in its scope must follow. \
                 It is written into AGENTS.md."
            }
        }
    }
}
