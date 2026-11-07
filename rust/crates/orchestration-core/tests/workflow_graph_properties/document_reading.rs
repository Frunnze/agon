use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::SkillId;
use orchestration_core::workflow::{AgentKind, Workflow, WorkflowAgent};
use proptest::collection::vec;
use proptest::option;
use proptest::prelude::*;
use uuid::Uuid;

use crate::branching_strategies::{branching_plan, build_branching_workflow};
use crate::entity_strategies::{agent_kind, runner_target};
use crate::workflow_strategies::workflow_from_parts;

pub const STEP_START: &str = "  - name: ";
pub const OUTCOMES_PREFIX: &str = "    outcomes: ";
const HEADER_LINE_COUNT: usize = 3;
const LARGEST_SKILL_COUNT: usize = 3;

pub type StepBlock<'document> = Vec<&'document str>;

pub fn approval_choice() -> impl Strategy<Value = Option<ApprovalPolicy>> {
    option::of(prop_oneof![
        Just(ApprovalPolicy::AskBeforeRiskyActions),
        Just(ApprovalPolicy::NeverAsk),
    ])
}

fn skill_identifier() -> impl Strategy<Value = SkillId> {
    any::<u128>().prop_map(|number| SkillId(Uuid::from_u128(number)))
}

pub fn agent_details() -> impl Strategy<Value = AgentDetails> {
    (
        option::of(agent_kind()),
        "[a-z ]{0,12}",
        runner_target(),
        vec(skill_identifier(), 0..=LARGEST_SKILL_COUNT),
        any::<bool>(),
        approval_choice(),
    )
        .prop_map(
            |(kind, task, runs_on, skills, uses_automatic_skills, choice)| {
                AgentDetails {
                    kind,
                    task,
                    runs_on,
                    skills,
                    uses_automatic_skills,
                    approval_policy: choice,
                }
            },
        )
}

#[derive(Clone, Debug)]
pub struct AgentDetails {
    pub kind: Option<AgentKind>,
    pub task: String,
    pub runs_on: RunnerTarget,
    pub skills: Vec<SkillId>,
    pub uses_automatic_skills: bool,
    pub approval_policy: Option<ApprovalPolicy>,
}

pub fn apply_details(
    agent: &WorkflowAgent,
    details: AgentDetails,
) -> WorkflowAgent {
    WorkflowAgent {
        kind: details.kind,
        task: details.task,
        runs_on: details.runs_on,
        skills: details.skills,
        uses_automatic_skills: details.uses_automatic_skills,
        approval_policy: details.approval_policy,
        ..agent.clone()
    }
}

pub fn document_workflow() -> impl Strategy<Value = Workflow> {
    branching_plan()
        .prop_map(|plan| build_branching_workflow(&plan))
        .prop_flat_map(|workflow| {
            let agent_count = workflow.agents.len();
            (Just(workflow), vec(agent_details(), agent_count))
        })
        .prop_map(|(workflow, details)| {
            let mut agents = Vec::new();
            for (agent, agent_details) in workflow.agents.iter().zip(details) {
                agents.push(apply_details(agent, agent_details));
            }
            workflow_from_parts(agents, workflow.connections.clone())
        })
}

pub fn list_step_blocks(document: &str) -> Vec<StepBlock<'_>> {
    let mut blocks: Vec<StepBlock<'_>> = Vec::new();
    for line in document.lines().skip(HEADER_LINE_COUNT) {
        if line.starts_with(STEP_START) {
            blocks.push(vec![line]);
        } else if let Some(block) = blocks.last_mut() {
            block.push(line);
        }
    }
    blocks
}

pub fn find_block<'document>(
    blocks: &[StepBlock<'document>],
    step_name: &str,
) -> Option<StepBlock<'document>> {
    let name_line = format!("{STEP_START}{step_name}");
    blocks.iter().find(|block| block[0] == name_line).cloned()
}

pub fn quote(text: &str) -> String {
    format!("\"{text}\"")
}

pub fn list_keys(block: &[&str]) -> Vec<String> {
    let mut keys = Vec::new();
    for line in block {
        let trimmed = line.trim_start().trim_start_matches("- ");
        if let Some((key, _)) = trimmed.split_once(':') {
            keys.push(key.to_owned());
        }
    }
    keys
}

pub fn lists_in_order(line: &str, texts: &[String]) -> bool {
    let mut search_from = 0;
    for text in texts {
        let Some(found_at) = line[search_from..].find(text.as_str()) else {
            return false;
        };
        search_from += found_at + text.len();
    }
    true
}

pub fn count_changed_lines(first: &str, second: &str) -> usize {
    first
        .lines()
        .zip(second.lines())
        .filter(|(first_line, second_line)| first_line != second_line)
        .count()
}

pub fn replace_agent(
    workflow: &Workflow,
    position: usize,
    replacement: WorkflowAgent,
) -> Workflow {
    let mut agents = workflow.agents.clone();
    agents[position] = replacement;
    workflow_from_parts(agents, workflow.connections.clone())
}

pub fn read_block_of<'document>(
    document: &'document str,
    step_name: &str,
) -> StepBlock<'document> {
    let blocks = list_step_blocks(document);
    find_block(&blocks, step_name).unwrap_or_default()
}

pub fn find_value<'document>(
    block: &[&'document str],
    prefix: &str,
) -> Option<&'document str> {
    block.iter().find_map(|line| line.strip_prefix(prefix))
}
