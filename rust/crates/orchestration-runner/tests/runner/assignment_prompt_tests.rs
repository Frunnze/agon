use orchestration_api::work::RunAssignment;
use orchestration_core::run::Run;
use orchestration_core::workflow::Workflow;
use orchestration_runner::assignment_prompt::compose_assignment_prompt;
use orchestration_runner::step_plan::plan_assigned_step;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::assignments::claude_assignment;
use crate::loop_runs::{
    DRAFT_INDEX, GATE_INDEX, LOOP_OUTCOME, finish_step, gate_loop_assignment,
    gate_loop_workflow,
};
use crate::support::{TestResult, to_case_error};
use crate::workflows::agent_name;

const EARLIER_ROUNDS_HEADING: &str = "## This step's earlier rounds";
const ROUND_HEADING_PREFIX: &str = "### Round ";
const LARGEST_ROUND_LIMIT: u32 = 4;
const SOLO_RUN_NUMBER: u128 = 0x9200;
const VERDICT_PATTERN: &str = "[a-z]{1,8}( [a-z]{1,8}){0,3}";
const DRAFT_RESULT: &str = "Drafted it.";

#[derive(Clone, Debug)]
struct LoopedGate {
    round_limit: u32,
    earlier_verdicts: Vec<String>,
}

fn any_looped_gate() -> impl Strategy<Value = LoopedGate> {
    (1..=LARGEST_ROUND_LIMIT).prop_flat_map(|round_limit| {
        let most_earlier_rounds =
            usize::try_from(round_limit).unwrap_or_default();
        let verdicts = vec(VERDICT_PATTERN, 1..=most_earlier_rounds);
        verdicts.prop_map(move |earlier_verdicts| LoopedGate {
            round_limit,
            earlier_verdicts,
        })
    })
}

fn finish_draft(run: &Run, workflow: &Workflow) -> TestResult<Run> {
    let draft_name = agent_name(DRAFT_INDEX);
    finish_step(run, workflow, &draft_name, DRAFT_RESULT, None)
}

fn finish_gate(
    run: &Run,
    workflow: &Workflow,
    verdict: &str,
) -> TestResult<Run> {
    let gate_name = agent_name(GATE_INDEX);
    finish_step(run, workflow, &gate_name, verdict, Some(LOOP_OUTCOME))
}

fn gate_assignment_after(gate: &LoopedGate) -> TestResult<RunAssignment> {
    let workflow = gate_loop_workflow(gate.round_limit);
    let mut assignment = gate_loop_assignment(gate.round_limit)?;
    let mut run = assignment.run.clone();
    for verdict in &gate.earlier_verdicts {
        run = finish_draft(&run, &workflow)?;
        run = finish_gate(&run, &workflow, verdict)?;
    }
    run = finish_draft(&run, &workflow)?;
    assignment.run = run;
    assignment.step_name = agent_name(GATE_INDEX);
    Ok(assignment)
}

fn prompt_for(
    assignment: &RunAssignment,
    repository_folders: &[String],
) -> TestResult<String> {
    let step = plan_assigned_step(assignment)?;
    Ok(compose_assignment_prompt(
        &step,
        assignment,
        repository_folders,
        &[],
    ))
}

fn find_in_order(text: &str, parts: &[String]) -> bool {
    let mut searched_from = 0;
    for part in parts {
        let Some(found_at) = text[searched_from..].find(part.as_str()) else {
            return false;
        };
        searched_from += found_at + part.len();
    }
    true
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(64))]

    #[test]
    fn test_compose_assignment_prompt_property_tells_the_round_and_history(
        gate in any_looped_gate(),
    ) {
        let assignment =
            gate_assignment_after(&gate).map_err(to_case_error)?;

        let prompt = prompt_for(&assignment, &[]).map_err(to_case_error)?;

        let current_round = gate.earlier_verdicts.len() + 1;
        let round_count = gate.round_limit + 1;
        let round_sentence = format!(
            "{EARLIER_ROUNDS_HEADING}\nThis is round {current_round} of \
             {round_count} of this step."
        );
        prop_assert!(prompt.contains(&round_sentence), "{}", prompt);
        let mut entries = vec![round_sentence];
        for (index, verdict) in gate.earlier_verdicts.iter().enumerate() {
            entries.push(format!(
                "{ROUND_HEADING_PREFIX}{}\nOutcome: {LOOP_OUTCOME}\n{verdict}",
                index + 1
            ));
        }
        prop_assert!(find_in_order(&prompt, &entries), "{}", prompt);
        let listed_rounds = prompt.matches(ROUND_HEADING_PREFIX).count();
        prop_assert_eq!(listed_rounds, gate.earlier_verdicts.len());
    }
}

#[test]
fn a_gate_in_its_first_round_gets_the_prompt_it_got_before() {
    let gate = LoopedGate {
        round_limit: 2,
        earlier_verdicts: Vec::new(),
    };
    let assignment = gate_assignment_after(&gate);
    let Ok(assignment) = assignment else {
        panic!("the first round is built: {assignment:?}");
    };

    let prompt = prompt_for(&assignment, &["app".to_owned()]);

    let expected = "step-1\nplease-outcome-changes\n\n\
        ## Where the code is\nYour working folder holds one folder per \
        repository. Change files only inside these folders; anything \
        outside them is lost when the run ends.\n- app/\n\n\
        ## Result from step-0\nDrafted it.\n\n\
        ## Outcome\nEnd your final message with one line OUTCOME: <name>, \
        where <name> is one of: approved, changes.";
    assert_eq!(prompt.ok().as_deref(), Some(expected));
}

#[test]
fn a_step_outside_any_loop_gets_the_prompt_it_got_before() {
    let assignment = claude_assignment(SOLO_RUN_NUMBER, "Fix the bug");
    let Ok(mut assignment) = assignment else {
        panic!("the assignment is built: {assignment:?}");
    };
    "Crashes on start.".clone_into(&mut assignment.task.details);

    let prompt = prompt_for(&assignment, &[]);

    let expected = "Fix the bug\n\n## Task details\nCrashes on start.";
    assert_eq!(prompt.ok().as_deref(), Some(expected));
}
