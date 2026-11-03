use orchestration_node::item_drafting::{DraftKind, DraftingContext};

const CHOICE_SEPARATOR: &str = ", ";
const LABEL_END: &str = ": ";
const WORK_LABELS: [&str; 11] = [
    "What should be done",
    "Details",
    "Project",
    "Who does it",
    "Runs on",
    "Where agents run",
    "Skills to use",
    "Automatic skills",
    "Commands",
    "Repeats",
    "Starts",
];
const PROJECT_LABELS: [&str; 3] = ["Name", "Repos", "What agents can do"];
const SKILL_LABELS: [&str; 5] = [
    "Name",
    "What it does",
    "When agents use it",
    "Applies to",
    "Instructions",
];
const RULE_LABELS: [&str; 3] = ["Rule", "Details", "Applies to"];

pub fn list_review_labels(kind: DraftKind) -> &'static [&'static str] {
    match kind {
        DraftKind::Task | DraftKind::Job => &WORK_LABELS,
        DraftKind::Project => &PROJECT_LABELS,
        DraftKind::Skill => &SKILL_LABELS,
        DraftKind::Rule => &RULE_LABELS,
    }
}

pub fn starts_with_review_label(kind: DraftKind, problem: &str) -> bool {
    list_review_labels(kind).iter().any(|label| {
        let labelled_start = format!("{label}{LABEL_END}");
        problem.starts_with(&labelled_start)
    })
}

pub fn join_choices(names: Vec<String>, last_choice: &str) -> String {
    let mut choices = names;
    choices.push(last_choice.to_owned());
    choices.join(CHOICE_SEPARATOR)
}

pub fn join_names(names: &[String]) -> String {
    names.join(CHOICE_SEPARATOR)
}

pub fn list_runner_names(context: &DraftingContext) -> Vec<String> {
    let mut names = Vec::new();
    for runner in &context.runners {
        names.push(runner.device.name.clone());
    }
    names
}

pub fn list_skill_names(context: &DraftingContext) -> Vec<String> {
    let mut names = Vec::new();
    for skill in &context.skills {
        names.push(skill.name.clone());
    }
    names
}

pub fn list_project_names(context: &DraftingContext) -> Vec<String> {
    let mut names = Vec::new();
    for project in &context.projects {
        names.push(project.name.clone());
    }
    names
}

pub fn list_signed_workflow_names(context: &DraftingContext) -> Vec<String> {
    let mut names = Vec::new();
    for workflow in &context.workflows {
        if workflow.is_signed {
            names.push(workflow.name.clone());
        }
    }
    names
}
