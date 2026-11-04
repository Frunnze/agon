use chrono::Utc;
use orchestration_api::work::RunEvent;
use orchestration_core::library::Skill;
use orchestration_core::run::StepStatus;

use crate::agent_invocation::AgentEnding;
use crate::agent_transcript::AgentTranscript;
use crate::approval_notes::describe_step_start;
use crate::branch_pusher::BranchPusher;
use crate::commit_publishing::{Publishing, publish_commits};
use crate::conversation::answer_user_messages;
use crate::run_context::RunContext;
use crate::run_error::RunError;
use crate::run_events::{post_run_events, step_status_changed};
use crate::runner_server::RunnerServer;
use crate::skill_proposals::hand_over_skill_improvements;
use crate::step_opening::{StepOpening, open_agent_conversation};
use crate::step_outcome::{OutcomeProblem, read_reported_outcome};
use crate::step_plan::StepPlan;
use crate::working_steps::Departure;
use crate::worktree_departure::{leave_worktree, leave_worktree_with_changes};

enum AgentWork {
    Finished(FinishedWork),
    Stopped(AgentEnding),
}

struct FinishedWork {
    transcript: AgentTranscript,
    outcome: Option<String>,
}

pub(crate) async fn execute_step<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    step: &StepPlan,
    skills: &[&Skill],
    opening: &StepOpening,
    answered_messages: usize,
) -> AgentEnding {
    let attempt =
        work_with_agent(context, step, opening, answered_messages).await;
    let agent_work = match attempt {
        Ok(agent_work) => agent_work,
        Err(problem) => {
            AgentWork::Stopped(AgentEnding::Failed(problem.to_string()))
        }
    };
    let finished_work = match agent_work {
        AgentWork::Finished(finished_work) => finished_work,
        AgentWork::Stopped(ending) => {
            leave_worktree(&context.workspace).await;
            return ending;
        }
    };

    let finishing = finish_step(context, step, skills, finished_work).await;
    match finishing {
        Ok(ending) => ending,
        Err(problem) => AgentEnding::Failed(problem.to_string()),
    }
}

async fn work_with_agent<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    step: &StepPlan,
    opening: &StepOpening,
    answered_messages: usize,
) -> Result<AgentWork, RunError> {
    let server = context.server.as_ref();
    let starting =
        describe_step_start(&step.name, step.approval_policy, Utc::now());
    post_run_events(server, context.run_id, starting).await?;

    let first_ending =
        open_agent_conversation(context, step, opening, answered_messages)
            .await?;
    let ending = answer_user_messages(context, step, first_ending).await?;
    let AgentEnding::Succeeded(transcript) = ending else {
        return Ok(AgentWork::Stopped(ending));
    };

    let outcome = read_step_outcome(step, &transcript)?;
    Ok(AgentWork::Finished(FinishedWork {
        transcript,
        outcome,
    }))
}

async fn finish_step<S: RunnerServer, P: BranchPusher>(
    context: &RunContext<S, P>,
    step: &StepPlan,
    skills: &[&Skill],
    finished_work: FinishedWork,
) -> Result<AgentEnding, RunError> {
    let departure =
        leave_worktree_with_changes(&context.workspace, step).await?;
    if departure == Departure::LastOut {
        let publishing = publish_commits(context, step).await?;
        if publishing == Publishing::Cancelled {
            return Ok(AgentEnding::Cancelled);
        }
    }

    let FinishedWork {
        transcript,
        outcome,
    } = finished_work;
    hand_over_skill_improvements(context, skills, &transcript).await;
    let mut finishing_events = Vec::new();
    if let Some(final_message) = &transcript.final_message {
        finishing_events.push(RunEvent::StepResultRecorded {
            step_name: step.name.clone(),
            result: final_message.clone(),
            outcome,
        });
    }
    finishing_events.push(step_status_changed(&step.name, StepStatus::Done));
    let server = context.server.as_ref();
    post_run_events(server, context.run_id, finishing_events).await?;
    Ok(AgentEnding::Succeeded(transcript))
}

fn read_step_outcome(
    step: &StepPlan,
    transcript: &AgentTranscript,
) -> Result<Option<String>, OutcomeProblem> {
    if step.outcome_choices.is_empty() {
        return Ok(None);
    }
    let final_message = transcript.final_message.as_deref();
    let outcome = read_reported_outcome(final_message, &step.outcome_choices)?;
    Ok(Some(outcome))
}
