use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{
    DeviceId, ProjectId, SkillId, WorkflowId, WorkspaceId,
};
use orchestration_core::library::SkillUsage;
use orchestration_core::scope::{ProjectScope, Scope, WorkspaceScope};
use orchestration_core::task::{Schedule, TaskDoer, TimeOfDay};
use orchestration_core::workflow::AgentKind;
use orchestration_core::workspace::{AgentAccess, Project, Repository};
use orchestration_node::item_drafting::{
    DraftKind, DraftingContext, DraftingDevice, DraftingRunner, DraftingSkill,
    DraftingWorkflow, DraftingWorkspace, ItemDraft, RuleDraft, SkillDraft,
    WorkDraft,
};
use proptest::prelude::*;
use uuid::Uuid;

pub const SAMPLE_WORKSPACE_NAME: &str = "acme";
pub const THIS_DEVICE_ID: &str = "a1b2c3";
pub const FOREIGN_DEVICE_ID: &str = "f0f0f0";
const FOREIGN_IDENTIFIER: u128 = 0xdead_beef;
const WORKSPACE_IDENTIFIER: u128 = 0x10;
const PROJECT_IDENTIFIER_BASE: u128 = 0x100;
const WORKFLOW_IDENTIFIER_BASE: u128 = 0x200;
const SKILL_IDENTIFIER_BASE: u128 = 0x300;
const MAXIMUM_LISTED: usize = 4;
const NAME_WORD_PATTERN: &str = "[a-z]{3,8}";
const MORNING_HOUR: u32 = 9;

pub fn kind_strategy() -> impl Strategy<Value = DraftKind> {
    prop_oneof![
        Just(DraftKind::Task),
        Just(DraftKind::Job),
        Just(DraftKind::Project),
        Just(DraftKind::Skill),
        Just(DraftKind::Rule),
    ]
}

pub fn describe_kind(kind: DraftKind) -> &'static str {
    match kind {
        DraftKind::Task => "task",
        DraftKind::Job => "job",
        DraftKind::Project => "project",
        DraftKind::Skill => "skill",
        DraftKind::Rule => "rule",
    }
}

pub fn kind_of(drafted: &ItemDraft) -> DraftKind {
    match drafted {
        ItemDraft::Task(_) => DraftKind::Task,
        ItemDraft::Job(_) => DraftKind::Job,
        ItemDraft::Project(_) => DraftKind::Project,
        ItemDraft::Skill(_) => DraftKind::Skill,
        ItemDraft::Rule(_) => DraftKind::Rule,
    }
}

pub fn sample_workspace_id() -> WorkspaceId {
    WorkspaceId(Uuid::from_u128(WORKSPACE_IDENTIFIER))
}

pub fn foreign_uuid() -> Uuid {
    Uuid::from_u128(FOREIGN_IDENTIFIER)
}

pub fn empty_context() -> DraftingContext {
    DraftingContext {
        workspace: DraftingWorkspace {
            id: sample_workspace_id(),
            name: SAMPLE_WORKSPACE_NAME.to_owned(),
        },
        this_device: DraftingDevice {
            id: DeviceId(THIS_DEVICE_ID.to_owned()),
            name: "air-laptop".to_owned(),
        },
        projects: Vec::new(),
        workflows: Vec::new(),
        skills: Vec::new(),
        runners: Vec::new(),
    }
}

pub fn sample_project(index: usize, name: &str, address: &str) -> Project {
    let offset = u128::try_from(index).unwrap_or_default();
    Project {
        id: ProjectId(Uuid::from_u128(PROJECT_IDENTIFIER_BASE + offset)),
        workspace_id: sample_workspace_id(),
        name: name.to_owned(),
        repositories: vec![Repository {
            address: address.to_owned(),
            default_branch: "main".to_owned(),
            agent_access: AgentAccess::PushAfterApproval,
        }],
    }
}

fn build_sample_context(
    word: &str,
    project_count: usize,
    workflow_count: usize,
    skill_count: usize,
    runner_count: usize,
) -> DraftingContext {
    let mut context = empty_context();
    for index in 0..project_count {
        let name = format!("{word}-{index}");
        let address = format!("github.com/{word}/repo-{index}");
        context
            .projects
            .push(sample_project(index, &name, &address));
    }
    for index in 0..workflow_count {
        let offset = u128::try_from(index).unwrap_or_default();
        context.workflows.push(DraftingWorkflow {
            id: WorkflowId(Uuid::from_u128(WORKFLOW_IDENTIFIER_BASE + offset)),
            name: format!("{word}-flow-{index}"),
            is_signed: true,
        });
    }
    for index in 0..skill_count {
        let offset = u128::try_from(index).unwrap_or_default();
        let usage = if index % 2 == 0 {
            SkillUsage::Automatic
        } else {
            SkillUsage::WhenChosen
        };
        context.skills.push(DraftingSkill {
            id: SkillId(Uuid::from_u128(SKILL_IDENTIFIER_BASE + offset)),
            name: format!("{word}-skill-{index}"),
            summary: format!("Helps with {word} number {index}"),
            usage,
        });
    }
    for index in 0..runner_count {
        let labels = (0..index).map(|label| format!("label-{label}"));
        context.runners.push(DraftingRunner {
            device: DraftingDevice {
                id: DeviceId(format!("{index:06x}")),
                name: format!("{word}-computer-{index}"),
            },
            is_online: index % 2 == 0,
            labels: labels.collect(),
        });
    }
    context
}

pub fn context_strategy() -> impl Strategy<Value = DraftingContext> {
    (
        NAME_WORD_PATTERN,
        1..MAXIMUM_LISTED,
        0..MAXIMUM_LISTED,
        0..MAXIMUM_LISTED,
        0..MAXIMUM_LISTED,
    )
        .prop_map(|(word, projects, workflows, skills, runners)| {
            build_sample_context(&word, projects, workflows, skills, runners)
        })
}

pub fn padded(text: &str) -> String {
    format!("  {text}\n\t")
}

pub fn valid_work_draft(
    context: &DraftingContext,
    title: &str,
    details: &str,
) -> WorkDraft {
    let doer = match context.workflows.first() {
        Some(workflow) => TaskDoer::Workflow {
            workflow_id: workflow.id,
        },
        None => TaskDoer::OneAgent {
            agent: AgentKind::ClaudeCode,
        },
    };
    let runs_on = match context.runners.first() {
        Some(runner) => RunnerTarget::SpecificRunner {
            device_id: runner.device.id.clone(),
        },
        None => RunnerTarget::RunnerWithLabels {
            labels: vec!["mac".to_owned()],
        },
    };
    WorkDraft {
        title: title.to_owned(),
        details: details.to_owned(),
        project_id: context.projects.first().map(|project| project.id),
        doer,
        runs_on,
        skills: context.skills.iter().map(|skill| skill.id).collect(),
        uses_automatic_skills: true,
        approval_policy: ApprovalPolicy::AskBeforeRiskyActions,
        schedule: Some(Schedule::Day {
            at: TimeOfDay {
                hour: MORNING_HOUR,
                minute: 0,
            },
        }),
    }
}

pub fn workspace_scope(context: &DraftingContext) -> Scope {
    Scope {
        workspaces: WorkspaceScope::OnlyWorkspaces {
            workspaces: vec![context.workspace.id],
        },
        projects: ProjectScope::OnlyProjects {
            projects: context
                .projects
                .iter()
                .map(|project| project.id)
                .collect(),
        },
    }
}

pub fn valid_skill_draft(
    context: &DraftingContext,
    name: &str,
    words: &str,
) -> SkillDraft {
    SkillDraft {
        name: name.to_owned(),
        summary: format!("Summary {words}"),
        instructions: format!("Instructions {words}"),
        scope: workspace_scope(context),
        usage: SkillUsage::WhenChosen,
    }
}

pub fn valid_rule_draft(context: &DraftingContext, words: &str) -> RuleDraft {
    RuleDraft {
        title: format!("Rule {words}"),
        details: format!("Details {words}"),
        scope: workspace_scope(context),
    }
}
