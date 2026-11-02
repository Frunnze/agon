use orchestration_core::naming::validate_name;
use orchestration_core::schedule_rules::ScheduleProblem;

pub(super) const EMPTY_WORK_TITLE: &str =
    "The agent wrote nothing for what should be done.";
pub(super) const UNKNOWN_WORKFLOW: &str =
    "The agent chose a workflow that does not exist here.";
pub(super) const UNKNOWN_SKILL: &str =
    "The agent chose a skill that does not exist here.";
pub(super) const JOB_WITHOUT_SCHEDULE: &str =
    "A job needs a schedule. Ask for changes and say how often it repeats.";
pub(super) const NO_REPOSITORY: &str =
    "The agent found no repo. Ask for changes and say where the code is.";
pub(super) const EMPTY_SKILL_SUMMARY: &str =
    "The agent wrote nothing for what the skill does.";
pub(super) const EMPTY_SKILL_INSTRUCTIONS: &str =
    "The agent wrote no instructions.";
pub(super) const EMPTY_RULE_TITLE: &str =
    "The agent wrote nothing for the rule.";
pub(super) const FOREIGN_WORKSPACE: &str =
    "The agent chose a workspace that does not exist here.";
pub(super) const EMPTY_SCOPE: &str = "The agent left the scope empty.";
const SENTENCE_END: char = '.';

pub(super) fn describe_missing_project(workspace_name: &str) -> String {
    format!(
        "No project in {workspace_name} fits this. Ask for changes and name \
         the project, or add the project first."
    )
}

pub(super) fn describe_foreign_project(workspace_name: &str) -> String {
    format!("The agent chose a project that is not in {workspace_name}.")
}

pub(super) fn describe_unsigned_workflow(workflow_name: &str) -> String {
    format!(
        "The workflow {workflow_name} is not signed yet, so it cannot do the \
         work."
    )
}

pub(super) fn describe_foreign_runner(workspace_name: &str) -> String {
    format!("The agent chose a runner that is not in {workspace_name}.")
}

pub(super) fn describe_invalid_schedule(problem: &ScheduleProblem) -> String {
    format!("The schedule is not valid: {problem}.")
}

pub(super) fn describe_taken_project_name(name: &str) -> String {
    format!("A project named {name} already exists.")
}

pub(super) fn describe_taken_skill_name(name: &str) -> String {
    format!("A skill named {name} already exists.")
}

pub(super) fn describe_missing_branch(address: &str) -> String {
    format!("The agent gave no branch for {address}.")
}

pub(super) fn find_name_problem(name: &str) -> Option<String> {
    let problem = validate_name(name).err()?;
    Some(write_sentence(&problem.to_string()))
}

pub(super) fn write_sentence(message: &str) -> String {
    let mut characters = message.chars();
    let first_character = characters.next();
    let capital: String = first_character
        .into_iter()
        .flat_map(char::to_uppercase)
        .collect();
    format!("{capital}{}{SENTENCE_END}", characters.as_str())
}
