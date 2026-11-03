use crate::document_diff::{DiffLine, diff_lines};
use crate::library::{Skill, SkillImprovement};

pub const SKILL_IMPROVEMENT_START: &str = "SKILL IMPROVEMENT:";
pub const SKILL_IMPROVEMENT_END: &str = "END SKILL IMPROVEMENT";
const SINGLE_LINE: usize = 1;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SkillImprovementProposal<'skills> {
    pub skill: &'skills Skill,
    pub instructions: String,
}

#[derive(Debug)]
struct ImprovementBlock {
    skill_name: String,
    instructions: String,
}

#[derive(Debug)]
struct OpenBlock<'message> {
    skill_name: String,
    lines: Vec<&'message str>,
}

#[must_use]
pub fn parse_skill_improvements<'skills>(
    final_message: &str,
    skills: &[&'skills Skill],
) -> Vec<SkillImprovementProposal<'skills>> {
    let mut proposals: Vec<SkillImprovementProposal> = Vec::new();
    for block in read_improvement_blocks(final_message) {
        let Some(skill) = find_improvable_skill(skills, &block.skill_name)
        else {
            continue;
        };
        let is_already_proposed = proposals
            .iter()
            .any(|proposal| proposal.skill.id == skill.id);
        let is_empty = block.instructions.is_empty();
        let is_unchanged = block.instructions == skill.instructions.trim();
        if is_already_proposed || is_empty || is_unchanged {
            continue;
        }

        proposals.push(SkillImprovementProposal {
            skill,
            instructions: block.instructions,
        });
    }
    proposals
}

#[must_use]
pub fn describe_instruction_change(
    current_instructions: &str,
    proposed_instructions: &str,
) -> String {
    let mut added_count = 0;
    let mut removed_count = 0;
    for line in diff_lines(current_instructions, proposed_instructions) {
        match line {
            DiffLine::Added(_) => added_count += 1,
            DiffLine::Removed(_) => removed_count += 1,
            DiffLine::Unchanged(_) => {}
        }
    }

    let added = count_lines(added_count);
    let removed = count_lines(removed_count);
    format!("{added} added, {removed} removed")
}

fn read_improvement_blocks(final_message: &str) -> Vec<ImprovementBlock> {
    let mut blocks = Vec::new();
    let mut open_block: Option<OpenBlock> = None;
    for line in final_message.lines() {
        let trimmed_line = line.trim();
        if let Some(skill_name) =
            trimmed_line.strip_prefix(SKILL_IMPROVEMENT_START)
        {
            open_block = Some(OpenBlock {
                skill_name: skill_name.trim().to_owned(),
                lines: Vec::new(),
            });
        } else if trimmed_line == SKILL_IMPROVEMENT_END {
            if let Some(finished_block) = open_block.take() {
                blocks.push(close_block(finished_block));
            }
        } else if let Some(unfinished_block) = open_block.as_mut() {
            unfinished_block.lines.push(line);
        }
    }
    blocks
}

fn close_block(open_block: OpenBlock) -> ImprovementBlock {
    let instructions = open_block.lines.join("\n");
    ImprovementBlock {
        skill_name: open_block.skill_name,
        instructions: instructions.trim().to_owned(),
    }
}

fn find_improvable_skill<'skills>(
    skills: &[&'skills Skill],
    skill_name: &str,
) -> Option<&'skills Skill> {
    let named_skill = skills.iter().find(|skill| skill.name == skill_name)?;
    if named_skill.improvement == SkillImprovement::Never {
        return None;
    }
    Some(named_skill)
}

fn count_lines(line_count: usize) -> String {
    if line_count == SINGLE_LINE {
        return format!("{line_count} line");
    }
    format!("{line_count} lines")
}
