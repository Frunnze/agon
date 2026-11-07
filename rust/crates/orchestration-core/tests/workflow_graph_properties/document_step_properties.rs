use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::workflow::{StepKind, Workflow, WorkflowAgent};
use orchestration_core::workflow_document::render_workflow_document;
use orchestration_core::workflow_graph::{agents_in_order, upstream_agents};
use proptest::prelude::*;

use crate::document_reading::{
    OUTCOMES_PREFIX, STEP_START, approval_choice, count_changed_lines,
    document_workflow, list_step_blocks, read_block_of, replace_agent,
};

const APPROVAL_KEY: &str = "asks_for_approval";

fn has_conditional_output(workflow: &Workflow, agent: &WorkflowAgent) -> bool {
    workflow.connections.iter().any(|connection| {
        connection.from == agent.id && connection.condition.is_some()
    })
}

fn render_choice_line(choice: Option<ApprovalPolicy>) -> &'static str {
    match choice {
        Some(ApprovalPolicy::AskBeforeRiskyActions) => {
            "    asks_for_approval: true"
        }
        Some(ApprovalPolicy::NeverAsk) => "    asks_for_approval: false",
        None => "    asks_for_approval: same as the project",
    }
}

fn with_approval_choice(
    workflow: &Workflow,
    position: usize,
    choice: Option<ApprovalPolicy>,
) -> Workflow {
    let agent = WorkflowAgent {
        step_kind: StepKind::Agent,
        approval_policy: choice,
        ..workflow.agents[position].clone()
    };
    replace_agent(workflow, position, agent)
}

fn render_expected_after(
    workflow: &Workflow,
    agent: &WorkflowAgent,
) -> String {
    let upstream_names: Vec<String> = upstream_agents(workflow, agent.id)
        .iter()
        .map(|upstream| upstream.name.clone())
        .collect();
    format!("    after: [{}]", upstream_names.join(", "))
}

proptest! {
    #[test]
    fn test_render_step_property_one_block_per_agent_in_run_order(
        workflow in document_workflow(),
    ) {
        let document = render_workflow_document(&workflow);

        let blocks = list_step_blocks(&document);
        let block_names: Vec<String> = blocks
            .iter()
            .map(|block| block[0].trim_start_matches(STEP_START).to_owned())
            .collect();
        let ordered_names: Vec<String> = agents_in_order(&workflow)
            .iter()
            .map(|agent| agent.name.clone())
            .collect();
        prop_assert_eq!(block_names, ordered_names);
        prop_assert!(document.ends_with('\n'));
        prop_assert!(!document.contains("\n\n"));
    }

    #[test]
    fn test_render_step_property_after_lists_upstream_in_run_order(
        workflow in document_workflow(),
    ) {
        let document = render_workflow_document(&workflow);

        for agent in &workflow.agents {
            let block = read_block_of(&document, &agent.name);
            let expected = render_expected_after(&workflow, agent);
            prop_assert!(block.contains(&expected.as_str()), "{expected}");
        }
    }

    #[test]
    fn test_render_step_property_outcomes_appear_only_after_a_fork(
        workflow in document_workflow(),
    ) {
        let document = render_workflow_document(&workflow);

        for agent in &workflow.agents {
            let block = read_block_of(&document, &agent.name);
            prop_assert!(!block.is_empty());
            let has_outcomes = block
                .last()
                .is_some_and(|line| line.starts_with(OUTCOMES_PREFIX));
            let is_fork = has_conditional_output(&workflow, agent);
            prop_assert_eq!(has_outcomes, is_fork);
        }
    }

    #[test]
    fn test_render_approval_choice_property_maps_each_choice_to_its_text(
        workflow in document_workflow(),
        choice in approval_choice(),
        pick in any::<prop::sample::Index>(),
    ) {
        let position = pick.index(workflow.agents.len());
        let name = workflow.agents[position].name.clone();
        let changed = with_approval_choice(&workflow, position, choice);

        let document = render_workflow_document(&changed);

        let block = read_block_of(&document, &name);
        prop_assert!(block.contains(&render_choice_line(choice)));
    }

    #[test]
    fn test_render_approval_choice_property_a_new_choice_changes_one_line(
        workflow in document_workflow(),
        first_choice in approval_choice(),
        second_choice in approval_choice(),
        pick in any::<prop::sample::Index>(),
    ) {
        let position = pick.index(workflow.agents.len());
        let first_workflow =
            with_approval_choice(&workflow, position, first_choice);
        let second_workflow =
            with_approval_choice(&workflow, position, second_choice);

        let first = render_workflow_document(&first_workflow);
        let second = render_workflow_document(&second_workflow);

        let expected_changes = usize::from(first_choice != second_choice);
        let changed_lines = count_changed_lines(&first, &second);
        prop_assert_eq!(first.lines().count(), second.lines().count());
        prop_assert_eq!(changed_lines, expected_changes);
    }

    #[test]
    fn test_render_approval_choice_property_person_steps_never_ask(
        workflow in document_workflow(),
    ) {
        let document = render_workflow_document(&workflow);

        for agent in &workflow.agents {
            let block = read_block_of(&document, &agent.name);
            let asks = block.iter().any(|line| line.contains(APPROVAL_KEY));
            prop_assert_eq!(asks, agent.step_kind == StepKind::Agent);
        }
    }
}
