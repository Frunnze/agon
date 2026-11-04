use std::sync::Arc;

use orchestration_core::run::{Run, RunStatus};
use orchestration_runner::run_executor::RunOutcome;
use tokio::runtime::Runtime;

use crate::executor_support::execute_with_git_pusher;
use crate::fake_agent::{
    local_configuration, prepare_agent_folders, read_prompt,
};
use crate::fake_server::FakeServer;
use crate::loop_runs::{
    DRAFT_INDEX, GATE_INDEX, apply_step_events, gate_loop_assignment,
    gate_loop_workflow,
};
use crate::support::TestResult;
use crate::workflows::agent_name;

const ROUND_LIMIT: u32 = 2;
const ROUND_COUNT: u32 = ROUND_LIMIT + 1;
const EARLIER_ROUNDS_HEADING: &str = "## This step's earlier rounds";
const FIRST_GATE_ROUND: &str =
    "### Round 1\nOutcome: changes\nfinished step-1\nOUTCOME: changes";

#[derive(Debug)]
struct CappedLoop {
    gate_prompts: Vec<String>,
    draft_prompt: String,
    run: Run,
}

fn run_capped_loop() -> TestResult<CappedLoop> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let workflow = gate_loop_workflow(ROUND_LIMIT);
    let mut assignment = gate_loop_assignment(ROUND_LIMIT)?;
    let runtime = Runtime::new()?;

    let mut gate_prompts = Vec::new();
    for _round in 0..ROUND_COUNT {
        for step_index in [DRAFT_INDEX, GATE_INDEX] {
            assignment.step_name = agent_name(step_index);
            let server = Arc::new(FakeServer::with_queue(Vec::new()));
            let outcome = runtime.block_on(execute_with_git_pusher(
                &server,
                &configuration,
                assignment.clone(),
            ))?;
            if outcome != RunOutcome::Finished {
                let step_name = &assignment.step_name;
                return Err(format!("{step_name} ended {outcome:?}").into());
            }
            let events = server.events_of(assignment.run.id);
            assignment.run =
                apply_step_events(&assignment.run, &workflow, &events)?;
        }
        gate_prompts.push(read_prompt(&folders, &agent_name(GATE_INDEX))?);
    }
    Ok(CappedLoop {
        gate_prompts,
        draft_prompt: read_prompt(&folders, &agent_name(DRAFT_INDEX))?,
        run: assignment.run,
    })
}

#[test]
fn a_capped_loop_tells_the_gate_its_round_and_its_earlier_verdicts() {
    let flow = run_capped_loop();

    let Ok(flow) = flow else {
        panic!("the capped loop runs to the end: {flow:?}");
    };
    let [first, second, third] = flow.gate_prompts.as_slice() else {
        panic!("the gate ran three rounds: {:?}", flow.gate_prompts);
    };
    assert!(!first.contains(EARLIER_ROUNDS_HEADING), "{first}");
    assert!(
        second.contains("This is round 2 of 3 of this step."),
        "{second}"
    );
    assert!(second.contains(FIRST_GATE_ROUND), "{second}");
    assert!(
        third.contains("This is round 3 of 3 of this step."),
        "{third}"
    );
    assert!(third.contains("### Round 2\nOutcome: changes"), "{third}");
    let draft = &flow.draft_prompt;
    assert!(draft.contains("## Result from step-1\n"), "{draft}");
    assert!(
        draft.contains("This is round 3 of 3 of this step."),
        "{draft}"
    );
    assert_eq!(flow.run.status, RunStatus::Done);
}
