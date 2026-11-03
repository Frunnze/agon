use orchestration_api::catalog::ImproveSkillRequest;
use orchestration_core::library::Skill;
use orchestration_core::skill_improvement::{
    describe_instruction_change, parse_skill_improvements,
};

use crate::agent_transcript::AgentTranscript;
use crate::branch_pusher::BranchPusher;
use crate::run_context::RunContext;
use crate::runner_log::log_skill_proposal_failure;
use crate::runner_server::RunnerServer;

pub(crate) async fn hand_over_skill_improvements<
    S: RunnerServer,
    P: BranchPusher,
>(
    context: &RunContext<S, P>,
    skills: &[&Skill],
    transcript: &AgentTranscript,
) {
    let Some(final_message) = &transcript.final_message else {
        return;
    };
    for proposal in parse_skill_improvements(final_message, skills) {
        let skill = proposal.skill;
        let summary = describe_instruction_change(
            &skill.instructions,
            &proposal.instructions,
        );
        let request = ImproveSkillRequest {
            run_id: context.run_id,
            summary,
            instructions: proposal.instructions,
        };

        let handed_over = context
            .server
            .propose_skill_improvement(skill.id, &request)
            .await;
        if let Err(problem) = handed_over {
            log_skill_proposal_failure(context.run_id, skill.id, &problem);
        }
    }
}
