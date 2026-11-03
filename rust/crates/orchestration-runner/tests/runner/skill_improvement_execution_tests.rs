use std::sync::Arc;

use orchestration_api::catalog::ImproveSkillRequest;
use orchestration_core::identifiers::{RunId, SkillId};
use orchestration_core::library::{
    Skill, SkillImprovement, SkillSource, SkillUsage,
};
use orchestration_core::scope::Scope;
use orchestration_runner::run_executor::RunOutcome;
use proptest::prelude::*;
use tokio::runtime::Runtime;
use uuid::Uuid;

use crate::assignments::{assignment_for, claude_task};
use crate::executor_support::{RUN_NUMBER, execute_with_git_pusher};
use crate::fake_agent::{
    local_configuration, prepare_agent_folders, read_prompt,
};
use crate::fake_server::FakeServer;
use crate::support::{TestResult, to_case_error};

const AGENT_NAME: &str = "step-0";
const IMPROVING_TITLE: &str = "step-0\nplease-improve-release";
const SKILL_NUMBER: u128 = 0x5c11;

#[derive(Debug)]
struct ImprovementRun {
    outcome: RunOutcome,
    prompt: String,
    run_id: RunId,
    proposals: Vec<(SkillId, ImproveSkillRequest)>,
}

fn release_skill(improvement: SkillImprovement) -> Skill {
    Skill {
        id: SkillId(Uuid::from_u128(SKILL_NUMBER)),
        name: "release".to_owned(),
        summary: "Ship the app".to_owned(),
        instructions: "Build once.".to_owned(),
        scope: Scope::everywhere(),
        usage: SkillUsage::WhenChosen,
        source: SkillSource::Created,
        improvement,
        history: Vec::new(),
    }
}

fn run_improving(
    improvement: SkillImprovement,
    server: FakeServer,
) -> TestResult<ImprovementRun> {
    let folders = prepare_agent_folders()?;
    let configuration = local_configuration(&folders, 1)?;
    let skill = release_skill(improvement);
    let mut task = claude_task(RUN_NUMBER, IMPROVING_TITLE);
    task.skills = vec![skill.id];
    let mut assignment = assignment_for(task, None, Vec::new(), RUN_NUMBER)?;
    assignment.skills = vec![skill];
    let run_id = assignment.run.id;
    let server = Arc::new(server);
    let runtime = Runtime::new()?;

    let outcome = runtime.block_on(execute_with_git_pusher(
        &server,
        &configuration,
        assignment,
    ))?;

    Ok(ImprovementRun {
        outcome,
        prompt: read_prompt(&folders, AGENT_NAME)?,
        run_id,
        proposals: server.skill_proposals(),
    })
}

fn improvable_setting() -> impl Strategy<Value = SkillImprovement> {
    prop_oneof![Just(SkillImprovement::AskMe), Just(SkillImprovement::Auto)]
}

#[test]
fn a_skill_set_to_never_gets_no_proposal() -> TestResult<()> {
    let server = FakeServer::with_queue(Vec::new());

    let run = run_improving(SkillImprovement::Never, server)?;

    assert_eq!(run.outcome, RunOutcome::Finished);
    assert!(!run.prompt.contains("## Improving skills"));
    assert_eq!(run.proposals, Vec::new());
    Ok(())
}

#[test]
fn a_refused_proposal_still_finishes_the_run() -> TestResult<()> {
    let server = FakeServer::with_queue(Vec::new()).refusing_skill_proposals();

    let run = run_improving(SkillImprovement::Auto, server)?;

    assert_eq!(run.outcome, RunOutcome::Finished);
    assert_eq!(run.proposals.len(), 1);
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(4))]

    #[test]
    fn test_execute_property_sends_the_proposal_with_its_run(
        setting in improvable_setting(),
    ) {
        let server = FakeServer::with_queue(Vec::new());

        let run = run_improving(setting, server).map_err(to_case_error)?;

        prop_assert_eq!(run.outcome, RunOutcome::Finished);
        prop_assert!(run.prompt.contains("version: release."));
        let expected_request = ImproveSkillRequest {
            run_id: run.run_id,
            summary: "1 line added, 1 line removed".to_owned(),
            instructions: "Build twice.".to_owned(),
        };
        let skill_id = SkillId(Uuid::from_u128(SKILL_NUMBER));
        prop_assert_eq!(run.proposals, vec![(skill_id, expected_request)]);
    }
}
