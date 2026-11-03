use crate::identifiers::WorkflowAgentId;
use crate::workflow::Workflow;

const APPROVAL_WORDS: [&str; 2] = ["approve", "approved"];

#[must_use]
pub fn list_step_choices(
    workflow: &Workflow,
    agent_id: WorkflowAgentId,
) -> Vec<String> {
    let mut choices = Vec::new();
    for connection in &workflow.connections {
        if connection.from != agent_id {
            continue;
        }
        if let Some(condition) = &connection.condition {
            choices.push(condition.clone());
        }
    }
    choices
}

#[must_use]
pub fn match_choice(answer: &str, choices: &[String]) -> Option<String> {
    let normalized_answer = answer.trim().to_lowercase();
    let exact_choice = choices
        .iter()
        .find(|choice| choice.to_lowercase() == normalized_answer);
    if let Some(choice) = exact_choice {
        return Some(choice.clone());
    }
    if !APPROVAL_WORDS.contains(&normalized_answer.as_str()) {
        return None;
    }
    choices
        .iter()
        .find(|choice| APPROVAL_WORDS.contains(&choice.as_str()))
        .cloned()
}
