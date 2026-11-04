use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{DeviceId, SkillId};
use orchestration_core::workflow::{
    AgentConnection, AgentKind, CanvasPosition, StepKind, Workflow,
    WorkflowAgent,
};
use orchestration_core::workflow_document::render_workflow_document;
use orchestration_core::workflow_graph::agents_in_order;
use proptest::prelude::*;
use uuid::Uuid;

use crate::entity_strategies::runner_target;
use crate::workflow_strategies::{
    acyclic_workflow, agent_identifier, arbitrary_workflow,
    workflow_from_parts,
};

const WORKFLOW_HEADER_LINES: usize = 3;
const LINES_PER_STEP: usize = 8;
const STEP_NAME_PREFIX: &str = "  - name: ";

fn design_agent(
    number: u128,
    name: &str,
    runs_on: RunnerTarget,
    vertical: f64,
) -> WorkflowAgent {
    WorkflowAgent {
        id: agent_identifier(number),
        name: name.to_owned(),
        kind: Some(AgentKind::ClaudeCode),
        task: String::new(),
        runs_on,
        skills: Vec::new(),
        uses_automatic_skills: false,
        approval_policy: Some(ApprovalPolicy::NeverAsk),
        position: CanvasPosition {
            horizontal: 0.0,
            vertical,
        },
        step_kind: StepKind::Agent,
    }
}

fn with_first_agent(
    workflow: &Workflow,
    change: impl Fn(WorkflowAgent) -> WorkflowAgent,
) -> Workflow {
    let mut agents = workflow.agents.clone();
    agents[0] = change(agents[0].clone());
    Workflow {
        agents,
        ..workflow.clone()
    }
}

fn is_hidden_character(character: char) -> bool {
    let is_line_break = character == '\n';
    let is_invisible = matches!(
        character,
        '\u{200B}'..='\u{200F}' | '\u{2028}'..='\u{202E}'
            | '\u{2060}'..='\u{2069}' | '\u{FEFF}'
    );
    (character.is_control() && !is_line_break) || is_invisible
}

#[test]
fn test_render_workflow_document_matches_the_release_layout() {
    let plan = WorkflowAgent {
        task: "Write the plan.\nKeep it \"short\".\u{2028}".to_owned(),
        skills: vec![SkillId(Uuid::from_u128(1))],
        uses_automatic_skills: true,
        approval_policy: Some(ApprovalPolicy::AskBeforeRiskyActions),
        ..design_agent(
            1,
            "plan",
            RunnerTarget::SpecificRunner {
                device_id: DeviceId("office-server".to_owned()),
            },
            0.0,
        )
    };
    let train = WorkflowAgent {
        kind: None,
        ..design_agent(
            2,
            "train",
            RunnerTarget::RunnerWithLabels {
                labels: vec!["gpu".to_owned()],
            },
            1.0,
        )
    };
    let connection = AgentConnection::plain(plan.id, train.id);
    let workflow = Workflow {
        name: "release".to_owned(),
        ..workflow_from_parts(vec![train, plan], vec![connection])
    };

    let document = render_workflow_document(&workflow);

    let expected = "name: release\n\
        available_in: all_workspaces\n\
        steps:\n  \
        - name: plan\n    \
        runs_on: office-server\n    \
        agent: claude-code\n    \
        after: []\n    \
        task: \"Write the plan.\\nKeep it \\\"short\\\".\\u2028\"\n    \
        skills: [\"00000000-0000-0000-0000-000000000001\"]\n    \
        automatic_skills: true\n    \
        asks_for_approval: true\n  \
        - name: train\n    \
        requires: [gpu]\n    \
        agent: not-set-up\n    \
        after: [plan]\n    \
        task: \"\"\n    \
        skills: []\n    \
        automatic_skills: false\n    \
        asks_for_approval: false\n";
    assert_eq!(document, expected);
}

fn approval_line(workflow: &Workflow) -> Option<String> {
    let document = render_workflow_document(workflow);
    document
        .lines()
        .find(|line| line.trim_start().starts_with("asks_for_approval:"))
        .map(|line| line.trim().to_owned())
}

proptest! {
    #[test]
    fn test_render_workflow_document_property_a_following_step_says_so(
        number in any::<u128>(),
    ) {
        let agent = WorkflowAgent {
            approval_policy: None,
            ..design_agent(number, "plan", RunnerTarget::AnyFreeRunner, 0.0)
        };
        let workflow = workflow_from_parts(vec![agent], Vec::new());

        let line = approval_line(&workflow);

        let expected = "asks_for_approval: same as the project";
        prop_assert_eq!(line.as_deref(), Some(expected));
    }

    #[test]
    fn test_render_workflow_document_property_stored_choices_keep_lines(
        asks in any::<bool>(),
    ) {
        let policy = if asks {
            ApprovalPolicy::AskBeforeRiskyActions
        } else {
            ApprovalPolicy::NeverAsk
        };
        let agent = WorkflowAgent {
            approval_policy: Some(policy),
            ..design_agent(1, "plan", RunnerTarget::AnyFreeRunner, 0.0)
        };
        let workflow = workflow_from_parts(vec![agent], Vec::new());

        let line = approval_line(&workflow);

        let expected = format!("asks_for_approval: {asks}");
        prop_assert_eq!(line, Some(expected));
    }

    #[test]
    fn test_render_workflow_document_property_steps_follow_agent_order(
        workflow in acyclic_workflow(),
    ) {
        let document = render_workflow_document(&workflow);

        let step_names: Vec<&str> = document
            .lines()
            .filter_map(|line| line.strip_prefix(STEP_NAME_PREFIX))
            .collect();
        let ordered_names: Vec<&str> = agents_in_order(&workflow)
            .iter()
            .map(|agent| agent.name.as_str())
            .collect();
        prop_assert_eq!(step_names, ordered_names);
    }

    #[test]
    fn test_render_workflow_document_property_ignores_agent_storage_order(
        workflow in acyclic_workflow(),
    ) {
        let mut reversed_agents = workflow.agents.clone();
        reversed_agents.reverse();
        let reversed = Workflow {
            agents: reversed_agents,
            ..workflow.clone()
        };

        prop_assert_eq!(
            render_workflow_document(&workflow),
            render_workflow_document(&reversed)
        );
    }

    #[test]
    fn test_render_workflow_document_property_task_text_changes_the_text(
        workflow in acyclic_workflow(),
        first_task in any::<String>(),
        second_task in any::<String>(),
    ) {
        let first = with_first_agent(&workflow, |agent| WorkflowAgent {
            task: first_task.clone(),
            ..agent
        });
        let second = with_first_agent(&workflow, |agent| WorkflowAgent {
            task: second_task.clone(),
            ..agent
        });

        let first_document = render_workflow_document(&first);
        let second_document = render_workflow_document(&second);

        prop_assert_eq!(
            first_document == second_document,
            first_task == second_task
        );
    }

    #[test]
    fn test_render_workflow_document_property_runner_changes_the_text(
        workflow in acyclic_workflow(),
        first_target in runner_target(),
        second_target in prop_oneof![
            runner_target(),
            Just(RunnerTarget::SpecificRunner {
                device_id: DeviceId("any free runner".to_owned()),
            }),
            Just(RunnerTarget::RunnerWithLabels { labels: Vec::new() }),
        ],
    ) {
        let first = with_first_agent(&workflow, |agent| WorkflowAgent {
            runs_on: first_target.clone(),
            ..agent
        });
        let second = with_first_agent(&workflow, |agent| WorkflowAgent {
            runs_on: second_target.clone(),
            ..agent
        });

        let first_document = render_workflow_document(&first);
        let second_document = render_workflow_document(&second);

        prop_assert_eq!(
            first_document == second_document,
            first_target == second_target
        );
    }

    #[test]
    fn test_render_workflow_document_property_ignores_canvas_moves_in_chains(
        workflow in acyclic_workflow(),
        vertical in any::<f64>(),
    ) {
        let mut chain = Vec::new();
        for pair in workflow.agents.windows(2) {
            chain.push(AgentConnection::plain(pair[0].id, pair[1].id));
        }
        let chained = Workflow { connections: chain, ..workflow.clone() };
        let moved = with_first_agent(&chained, |agent| WorkflowAgent {
            position: CanvasPosition { horizontal: vertical, vertical },
            ..agent
        });

        prop_assert_eq!(
            render_workflow_document(&chained),
            render_workflow_document(&moved)
        );
    }

    #[test]
    fn test_render_workflow_document_fuzz_text_cannot_add_or_hide_lines(
        workflow in arbitrary_workflow(),
        name in any::<String>(),
    ) {
        let renamed = Workflow { name, ..workflow };

        let document = render_workflow_document(&renamed);

        let expected_line_count =
            WORKFLOW_HEADER_LINES + LINES_PER_STEP * renamed.agents.len();
        prop_assert_eq!(document.lines().count(), expected_line_count);
        prop_assert!(!document.chars().any(is_hidden_character));
    }
}
