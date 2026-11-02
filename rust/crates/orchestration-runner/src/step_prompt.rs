use orchestration_core::library::Skill;

const SECTION_SEPARATOR: &str = "\n\n";
const TASK_DETAILS_HEADING: &str = "## Task details";
const SKILL_HEADING_PREFIX: &str = "## Skill: ";
const UPSTREAM_HEADING_PREFIX: &str = "## Result from ";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct UpstreamResult {
    pub step_name: String,
    pub final_message: String,
}

#[must_use]
pub fn compose_step_prompt(
    instruction: &str,
    task_details: &str,
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
