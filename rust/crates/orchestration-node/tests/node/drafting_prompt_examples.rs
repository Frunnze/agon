use orchestration_core::identifiers::{DeviceId, SkillId, WorkflowId};
use orchestration_core::library::SkillUsage;
use orchestration_core::workspace::{AgentAccess, Repository};
use orchestration_node::item_drafting::{
    DraftChange, DraftKind, DraftingContext, DraftingDevice, DraftingRunner,
    DraftingSkill, DraftingWorkflow, render_drafting_prompt,
};
use serde_json::json;
use uuid::Uuid;

use crate::support::drafting_samples::{
    THIS_DEVICE_ID, empty_context, sample_project,
};

fn sample_listed_context() -> DraftingContext {
    let mut context = empty_context();
    let mut billing = sample_project(0, "billing", "github.com/acme/billing");
    billing.repositories.push(Repository {
        address: "local:a1b2c3:/Users/someone/api".to_owned(),
        default_branch: "main".to_owned(),
        agent_access: AgentAccess::ReadOnly,
    });
    context.projects.push(billing);
    context.workflows = vec![
        DraftingWorkflow {
            id: WorkflowId(Uuid::from_u128(3)),
            name: "release".to_owned(),
            is_signed: true,
        },
        DraftingWorkflow {
            id: WorkflowId(Uuid::from_u128(4)),
            name: "review".to_owned(),
            is_signed: false,
        },
    ];
    context.skills = vec![
        DraftingSkill {
            id: SkillId(Uuid::from_u128(5)),
            name: "release-notes".to_owned(),
            summary: "Write release notes".to_owned(),
            usage: SkillUsage::Automatic,
        },
        DraftingSkill {
            id: SkillId(Uuid::from_u128(6)),
            name: "ios".to_owned(),
            summary: "Build the app".to_owned(),
            usage: SkillUsage::WhenChosen,
        },
    ];
    context.runners = vec![
        DraftingRunner {
            device: DraftingDevice {
                id: DeviceId(THIS_DEVICE_ID.to_owned()),
                name: "air-laptop".to_owned(),
            },
            is_online: true,
            labels: vec!["mac".to_owned(), "arm".to_owned()],
        },
        DraftingRunner {
            device: DraftingDevice {
                id: DeviceId("d4e5f6".to_owned()),
                name: "studio".to_owned(),
            },
            is_online: false,
            labels: Vec::new(),
        },
    ];
    context
}

#[test]
fn a_prompt_lists_the_context_in_the_agreed_line_format() {
    let context = sample_listed_context();

    let prompt = render_drafting_prompt(
        &context,
        DraftKind::Task,
        "Ship it",
        Some("the billing page"),
        None,
        &[],
    );

    let expected_start = "Draft a new task.\n\
        A task is one piece of work that one agent or a workflow does in a \
        project. If the person wants it to repeat, give it a schedule.\n\
        Workspace: acme (id 00000000-0000-0000-0000-000000000010)\n\
        This computer: air-laptop (id a1b2c3)\n\
        Projects:\n\
        - billing (id 00000000-0000-0000-0000-000000000100): \
        github.com/acme/billing, local:a1b2c3:/Users/someone/api\n\
        Workflows:\n\
        - release (id 00000000-0000-0000-0000-000000000003), signed\n\
        - review (id 00000000-0000-0000-0000-000000000004), not signed yet\n\
        Skills:\n\
        - release-notes (id 00000000-0000-0000-0000-000000000005), \
        automatic: Write release notes\n\
        - ios (id 00000000-0000-0000-0000-000000000006), when chosen: \
        Build the app\n\
        Runners:\n\
        - air-laptop (id a1b2c3), online, labels: mac, arm\n\
        - studio (id d4e5f6), offline\n\
        Started from: the billing page\n\
        What the person wants:\n\
        Ship it\n\
        \n\
        Reply with one JSON object and nothing else.";
    let Ok(prompt) = prompt else {
        panic!("the prompt renders: {prompt:?}");
    };
    assert!(prompt.starts_with(expected_start), "{prompt}");
}

#[test]
fn a_change_prompt_shows_the_current_draft_and_the_note() {
    let context = sample_listed_context();
    let change = DraftChange {
        draft: json!({ "title": "Rule" }),
        note: "Make it stricter".to_owned(),
    };

    let prompt = render_drafting_prompt(
        &context,
        DraftKind::Rule,
        "No pushes on Friday",
        None,
        Some(&change),
        &[],
    );

    let expected_part = "What the person wants:\n\
        No pushes on Friday\n\
        Current draft:\n\
        {\n  \"title\": \"Rule\"\n}\n\
        Requested change:\n\
        Make it stricter\n\
        \n\
        Reply with one JSON object and nothing else.";
    let Ok(prompt) = prompt else {
        panic!("the prompt renders: {prompt:?}");
    };
    assert!(prompt.contains(expected_part), "{prompt}");
    assert!(!prompt.contains("Started from:"), "{prompt}");
}
