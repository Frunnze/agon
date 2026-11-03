use orchestration_core::library::Skill;

const SECTION_SEPARATOR: &str = "\n\n";
const TASK_DETAILS_HEADING: &str = "## Task details";
const SKILL_HEADING_PREFIX: &str = "## Skill: ";
const UPSTREAM_HEADING_PREFIX: &str = "## Result from ";
const REPOSITORY_FOLDERS_HEADING: &str = "## Where the code is";
const REPOSITORY_FOLDERS_GUIDANCE: &str = "Your working folder holds one \
    folder per repository. Change files only inside these folders; \
    anything outside them is lost when the run ends.";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct UpstreamResult {
    pub step_name: String,
    pub final_message: String,
}

#[must_use]
pub fn compose_step_prompt(
    instruction: &str,
    task_details: &str,
    repository_folders: &[String],
    skills: &[&Skill],
    upstream_results: &[UpstreamResult],
) -> String {
    let mut sections = Vec::new();
    if !instruction.trim().is_empty() {
        sections.push(instruction.to_string());
    }
    if !task_details.trim().is_empty() {
        sections.push(format!("{TASK_DETAILS_HEADING}\n{task_details}"));
    }
    if !repository_folders.is_empty() {
        sections.push(describe_repository_folders(repository_folders));
    }
    for skill in skills {
        let heading = format!("{SKILL_HEADING_PREFIX}{}", skill.name);
        sections.push(format!("{heading}\n{}", skill.instructions));
    }
    for upstream in upstream_results {
        let heading =
            format!("{UPSTREAM_HEADING_PREFIX}{}", upstream.step_name);
        sections.push(format!("{heading}\n{}", upstream.final_message));
    }
    sections.join(SECTION_SEPARATOR)
}

fn describe_repository_folders(repository_folders: &[String]) -> String {
    let mut lines = vec![
        REPOSITORY_FOLDERS_HEADING.to_string(),
        REPOSITORY_FOLDERS_GUIDANCE.to_string(),
    ];
    for folder in repository_folders {
        lines.push(format!("- {folder}/"));
    }
    lines.join("\n")
}
