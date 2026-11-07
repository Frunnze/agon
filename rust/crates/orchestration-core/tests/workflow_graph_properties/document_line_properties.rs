use orchestration_core::workflow::{
    AgentKind, StepKind, Workflow, WorkflowAgent,
};
use orchestration_core::workflow_document::render_workflow_document;
use proptest::prelude::*;

use crate::document_reading::{
    AgentDetails, OUTCOMES_PREFIX, agent_details, apply_details,
    document_workflow, find_value, list_keys, lists_in_order, read_block_of,
    replace_agent,
};

const AGENT_KEYS: [&str; 8] = [
    "name",
    "runs_on|requires",
    "agent",
    "after",
    "task",
    "skills",
    "automatic_skills",
    "asks_for_approval",
];
const PERSON_KEYS: [&str; 4] = ["name", "kind", "after", "question"];
const OUTCOMES_KEY: &str = "outcomes";
const KEY_CHOICE_SEPARATOR: char = '|';
const SKILLS_PREFIX: &str = "    skills: [";
const TASK_PREFIX: &str = "    task: ";
const QUESTION_PREFIX: &str = "    question: ";
const PERSON_KIND_LINE: &str = "    kind: person";
const LIST_SEPARATOR: &str = ", ";

fn matches_key(key: &str, expected: &str) -> bool {
    expected
        .split(KEY_CHOICE_SEPARATOR)
        .any(|choice| choice == key)
}

fn has_keys(keys: &[String], expected: &[&str]) -> bool {
    let without_outcomes: Vec<&String> =
        keys.iter().filter(|key| *key != OUTCOMES_KEY).collect();
    let is_same_count = without_outcomes.len() == expected.len();
    let are_in_order = without_outcomes
        .iter()
        .zip(expected)
        .all(|(key, expected_key)| matches_key(key, expected_key));
    is_same_count && are_in_order
}

fn label_kind(kind: Option<AgentKind>) -> &'static str {
    match kind {
        Some(AgentKind::ClaudeCode) => "claude-code",
        Some(AgentKind::Codex) => "codex",
        Some(AgentKind::GeminiCli) => "gemini-cli",
        None => "not-set-up",
    }
}

fn list_steps_of_kind(
    workflow: &Workflow,
    step_kind: StepKind,
) -> Vec<&WorkflowAgent> {
    workflow
        .agents
        .iter()
        .filter(|agent| agent.step_kind == step_kind)
        .collect()
}

fn as_step_kind(agent: &WorkflowAgent, step_kind: StepKind) -> WorkflowAgent {
    WorkflowAgent {
        step_kind,
        ..agent.clone()
    }
}

proptest! {
    #[test]
    fn test_render_agent_lines_property_keep_the_fixed_key_order(
        workflow in document_workflow(),
    ) {
        let document = render_workflow_document(&workflow);

        for agent in &workflow.agents {
            let keys = list_keys(&read_block_of(&document, &agent.name));
            let expected: &[&str] = match agent.step_kind {
                StepKind::Agent => &AGENT_KEYS,
                StepKind::Person => &PERSON_KEYS,
            };
            prop_assert!(has_keys(&keys, expected), "{keys:?}");
        }
    }

    #[test]
    fn test_render_agent_lines_property_skills_keep_their_stored_order(
        workflow in document_workflow(),
    ) {
        let document = render_workflow_document(&workflow);

        for agent in list_steps_of_kind(&workflow, StepKind::Agent) {
            let skill_texts: Vec<String> = agent
                .skills
                .iter()
                .map(|skill_id| skill_id.0.to_string())
                .collect();
            let block = read_block_of(&document, &agent.name);
            let skills = find_value(&block, SKILLS_PREFIX).unwrap_or_default();
            let separator_count = skills.matches(LIST_SEPARATOR).count();
            let expected_count = skill_texts.len().saturating_sub(1);
            prop_assert!(lists_in_order(skills, &skill_texts));
            prop_assert_eq!(separator_count, expected_count);
        }
    }

    #[test]
    fn test_render_agent_lines_property_names_the_agent_and_automation(
        workflow in document_workflow(),
    ) {
        let document = render_workflow_document(&workflow);

        for agent in list_steps_of_kind(&workflow, StepKind::Agent) {
            let agent_line = format!("    agent: {}", label_kind(agent.kind));
            let automatic = agent.uses_automatic_skills;
            let automatic_line = format!("    automatic_skills: {automatic}");
            let block = read_block_of(&document, &agent.name);
            prop_assert!(block.contains(&agent_line.as_str()));
            prop_assert!(block.contains(&automatic_line.as_str()));
        }
    }

    #[test]
    fn test_render_person_lines_property_ask_the_task_as_the_question(
        workflow in document_workflow(),
        pick in any::<prop::sample::Index>(),
    ) {
        let position = pick.index(workflow.agents.len());
        let agent = &workflow.agents[position];
        let as_agent = as_step_kind(agent, StepKind::Agent);
        let as_person = as_step_kind(agent, StepKind::Person);
        let agent_workflow = replace_agent(&workflow, position, as_agent);
        let person_workflow = replace_agent(&workflow, position, as_person);

        let agent_document = render_workflow_document(&agent_workflow);
        let person_document = render_workflow_document(&person_workflow);

        let agent_block = read_block_of(&agent_document, &agent.name);
        let person_block = read_block_of(&person_document, &agent.name);
        let task_text = find_value(&agent_block, TASK_PREFIX);
        let question_text = find_value(&person_block, QUESTION_PREFIX);
        prop_assert!(task_text.is_some());
        prop_assert_eq!(task_text, question_text);
        prop_assert!(person_block.contains(&PERSON_KIND_LINE));
    }

    #[test]
    fn test_render_person_lines_property_ignore_what_only_agents_use(
        workflow in document_workflow(),
        pick in any::<prop::sample::Index>(),
        details in agent_details(),
    ) {
        let position = pick.index(workflow.agents.len());
        let stored = &workflow.agents[position];
        let person = as_step_kind(stored, StepKind::Person);
        let changed_details = AgentDetails {
            task: person.task.clone(),
            ..details
        };
        let changed_person = apply_details(&person, changed_details);
        let first_workflow = replace_agent(&workflow, position, person);
        let second_workflow =
            replace_agent(&workflow, position, changed_person);

        let first = render_workflow_document(&first_workflow);
        let second = render_workflow_document(&second_workflow);

        prop_assert_eq!(first, second);
    }

    #[test]
    fn test_render_person_lines_property_hold_exactly_four_lines(
        workflow in document_workflow(),
    ) {
        let document = render_workflow_document(&workflow);

        for agent in list_steps_of_kind(&workflow, StepKind::Person) {
            let block = read_block_of(&document, &agent.name);
            let line_count = block
                .iter()
                .filter(|line| !line.starts_with(OUTCOMES_PREFIX))
                .count();
            prop_assert_eq!(line_count, PERSON_KEYS.len());
        }
    }
}
