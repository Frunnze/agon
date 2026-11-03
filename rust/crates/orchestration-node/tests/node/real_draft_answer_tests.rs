use orchestration_core::agent_place::AgentPlace;
use orchestration_core::identifiers::{DeviceId, SkillId, WorkflowId};
use orchestration_core::library::SkillUsage;
use orchestration_node::item_drafting::{
    CheckedDraft, DraftKind, DraftingContext, DraftingDevice, DraftingRunner,
    DraftingSkill, DraftingWorkflow, ItemDraft, check_item_draft,
    parse_item_answer,
};
use uuid::Uuid;

use crate::support::drafting_samples::{
    THIS_DEVICE_ID, empty_context, sample_project,
};

const TASK_ANSWER: &str = include_str!("../fixtures/draft_answers/task.json");
const JOB_ANSWER: &str = include_str!("../fixtures/draft_answers/job.json");
const RULE_ANSWER: &str = include_str!("../fixtures/draft_answers/rule.json");
const SKILL_ANSWER: &str =
    include_str!("../fixtures/draft_answers/skill.json");
const PROJECT_ANSWER: &str =
    include_str!("../fixtures/draft_answers/project.json");
const WORKFLOW_IDENTIFIER: u128 = 0x200;
const WHEN_CHOSEN_SKILL_IDENTIFIER: u128 = 0x300;
const AUTOMATIC_SKILL_IDENTIFIER: u128 = 0x301;
const UNNAMED_PROJECT_PROBLEM: &str = "Project: the agent could not tell \
                                       which one. Ask for changes and name \
                                       one of: web-app, api.";

fn sample_runner(
    device_id: &str,
    name: &str,
    is_online: bool,
    label: &str,
    offer: AgentPlace,
) -> DraftingRunner {
    DraftingRunner {
        device: DraftingDevice {
            id: DeviceId(device_id.to_owned()),
            name: name.to_owned(),
        },
        is_online,
        labels: vec![label.to_owned()],
        offers: vec![offer],
    }
}

fn sample_skill(
    identifier: u128,
    name: &str,
    usage: SkillUsage,
) -> DraftingSkill {
    DraftingSkill {
        id: SkillId(Uuid::from_u128(identifier)),
        name: name.to_owned(),
        summary: format!("Helps with {name}"),
        usage,
    }
}

fn drafted_context() -> DraftingContext {
    let mut context = empty_context();
    context.projects = vec![
        sample_project(0, "web-app", "github.com/acme/web-app"),
        sample_project(1, "api", "github.com/acme/api"),
    ];
    context.workflows = vec![DraftingWorkflow {
        id: WorkflowId(Uuid::from_u128(WORKFLOW_IDENTIFIER)),
        name: "review-then-merge".to_owned(),
        is_signed: true,
    }];
    context.skills = vec![
        sample_skill(
            WHEN_CHOSEN_SKILL_IDENTIFIER,
            "write-tests",
            SkillUsage::WhenChosen,
        ),
        sample_skill(
            AUTOMATIC_SKILL_IDENTIFIER,
            "commit-style",
            SkillUsage::Automatic,
        ),
    ];
    let this_computer = sample_runner(
        THIS_DEVICE_ID,
        "air-laptop",
        true,
        "mac",
        AgentPlace::LocalProcess,
    );
    let build_box = sample_runner(
        "d4e5f6",
        "build-box",
        false,
        "linux",
        AgentPlace::Container,
    );
    context.runners = vec![this_computer, build_box];
    context
}

fn check_real_answer(
    context: &DraftingContext,
    kind: DraftKind,
    answer: &str,
) -> CheckedDraft {
    let parsed = parse_item_answer(kind, answer);
    let Ok(drafted) = parsed else {
        panic!("the real {kind:?} answer parses: {parsed:?}");
    };
    check_item_draft(context, &drafted)
}

#[test]
fn real_answers_to_ordinary_requests_come_back_complete() {
    let context = drafted_context();
    let real_answers = [
        (DraftKind::Task, TASK_ANSWER),
        (DraftKind::Rule, RULE_ANSWER),
        (DraftKind::Skill, SKILL_ANSWER),
        (DraftKind::Project, PROJECT_ANSWER),
    ];

    for (kind, answer) in real_answers {
        let checked = check_real_answer(&context, kind, answer);

        assert!(checked.problems.is_empty(), "{kind:?}: {checked:?}");
    }
}

#[test]
fn a_real_weekly_job_without_a_project_names_the_projects_to_pick() {
    let context = drafted_context();

    let checked = check_real_answer(&context, DraftKind::Job, JOB_ANSWER);

    assert_eq!(checked.problems, vec![UNNAMED_PROJECT_PROBLEM.to_owned()]);
}

#[test]
fn a_real_weekly_job_takes_the_only_project_of_the_workspace() {
    let mut context = drafted_context();
    context.projects.truncate(1);
    let only_project_id = context.projects.first().map(|project| project.id);

    let checked = check_real_answer(&context, DraftKind::Job, JOB_ANSWER);

    assert!(checked.problems.is_empty(), "{checked:?}");
    let ItemDraft::Job(work) = checked.draft else {
        panic!("the draft is a job: {checked:?}");
    };
    assert_eq!(work.project_id, only_project_id);
}
