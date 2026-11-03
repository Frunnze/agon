use std::fmt::Display;

use orchestration_core::naming::validate_name;
use orchestration_core::schedule_rules::ScheduleProblem;

pub(super) const EMPTY_WORK_TITLE: &str = "What should be done: it is empty. \
                                           Ask for changes and say what \
                                           should be done.";
pub(super) const JOB_WITHOUT_SCHEDULE: &str = "Repeats: a job needs a \
                                               schedule. Ask for changes and \
                                               say how often it repeats.";
pub(super) const NO_REPOSITORY: &str =
    "Repos: none found. Ask for changes and say where the code is.";
pub(super) const EMPTY_SKILL_SUMMARY: &str = "What it does: it is empty. Ask \
                                              for changes and say what the \
                                              skill does.";
pub(super) const EMPTY_SKILL_INSTRUCTIONS: &str = "Instructions: they are \
                                                   empty. Ask for changes and \
                                                   say what agents should \
                                                   do.";
pub(super) const EMPTY_RULE_TITLE: &str = "Rule: it is empty. Ask for \
                                           changes and say what agents must \
                                           follow.";
pub(super) const FOREIGN_WORKSPACE: &str = "Applies to: the chosen workspace \
                                            does not exist here. Ask for \
                                            changes and say this workspace \
                                            or everywhere.";
pub(super) const EMPTY_SCOPE: &str =
    "Applies to: it is empty. Ask for changes and say where it applies.";
const CHOICE_SEPARATOR: &str = ", ";
const ONE_AGENT_CHOICE: &str = "one agent";
const ANY_FREE_RUNNER_CHOICE: &str = "any free runner";
const NO_SKILL_CHOICE: &str = "none";
const ALL_PROJECTS_CHOICE: &str = "all projects";
const ANOTHER_NAME_FIX: &str = "Ask for changes and give another name.";
const REPOSITORY_FIX: &str = "Ask for changes and give a GitHub address or a \
                              git folder on this computer.";

pub(super) fn describe_missing_project(
    workspace_name: &str,
    project_names: &[&str],
) -> String {
    if project_names.is_empty() {
        return describe_workspace_without_projects(workspace_name);
    }
    format!(
        "Project: the agent could not tell which one. Ask for changes and \
         name one of: {}.",
        project_names.join(CHOICE_SEPARATOR)
    )
}

pub(super) fn describe_foreign_project(
    workspace_name: &str,
    project_names: &[&str],
) -> String {
    if project_names.is_empty() {
        return describe_workspace_without_projects(workspace_name);
    }
    format!(
        "Project: the chosen one is not in {workspace_name}. Ask for changes \
         and name one of: {}.",
        project_names.join(CHOICE_SEPARATOR)
    )
}

pub(super) fn describe_foreign_scope_project(
    workspace_name: &str,
    project_names: &[&str],
) -> String {
    format!(
        "Applies to: a chosen project is not in {workspace_name}. Ask for \
         changes and name one of: {}.",
        join_choices(project_names, ALL_PROJECTS_CHOICE)
    )
}

pub(super) fn describe_unknown_workflow(signed_names: &[&str]) -> String {
    format!(
        "Who does it: the chosen workflow does not exist here. Ask for \
         changes and name one of: {}.",
        join_choices(signed_names, ONE_AGENT_CHOICE)
    )
}

pub(super) fn describe_unsigned_workflow(
    workflow_name: &str,
    signed_names: &[&str],
) -> String {
    format!(
        "Who does it: the workflow {workflow_name} is not signed yet. Ask for \
         changes and name one of: {}.",
        join_choices(signed_names, ONE_AGENT_CHOICE)
    )
}

pub(super) fn describe_foreign_runner(
    workspace_name: &str,
    runner_names: &[&str],
) -> String {
    format!(
        "Runs on: the chosen runner is not in {workspace_name}. Ask for \
         changes and name one of: {}.",
        join_choices(runner_names, ANY_FREE_RUNNER_CHOICE)
    )
}

pub(super) fn describe_unknown_skill(skill_names: &[&str]) -> String {
    format!(
        "Skills to use: a chosen skill does not exist here. Ask for changes \
         and name one of: {}.",
        join_choices(skill_names, NO_SKILL_CHOICE)
    )
}

pub(super) fn describe_invalid_schedule(problem: &ScheduleProblem) -> String {
    format!("Repeats: {problem}. Ask for changes and give a valid time.")
}

pub(super) fn describe_taken_project_name(name: &str) -> String {
    format!("Name: a project named {name} already exists. {ANOTHER_NAME_FIX}")
}

pub(super) fn describe_taken_skill_name(name: &str) -> String {
    format!("Name: a skill named {name} already exists. {ANOTHER_NAME_FIX}")
}

pub(super) fn describe_repository_problem(problem: impl Display) -> String {
    format!("Repos: {problem}. {REPOSITORY_FIX}")
}

pub(super) fn find_name_problem(name: &str) -> Option<String> {
    let problem = validate_name(name).err()?;
    Some(format!("Name: {problem}. {ANOTHER_NAME_FIX}"))
}

fn describe_workspace_without_projects(workspace_name: &str) -> String {
    format!(
        "Project: {workspace_name} has no projects yet. Add a project first, \
         then draft this again."
    )
}

fn join_choices(names: &[&str], last_choice: &str) -> String {
    let mut choices = names.to_vec();
    choices.push(last_choice);
    choices.join(CHOICE_SEPARATOR)
}
