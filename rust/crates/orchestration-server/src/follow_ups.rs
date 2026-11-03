use orchestration_api::work::FollowUp;
use orchestration_core::run::{ChatAuthor, ChatMessage, RunStep, StepStatus};
use orchestration_core::run_lifecycle::is_run_finished;

use crate::run_changes::{reopen_run, requeue_step};
use crate::stored_state::RunRecord;

pub fn append_chat_message(
    record: &RunRecord,
    message: &ChatMessage,
) -> RunRecord {
    let follow_up_step = find_follow_up_step(record, message);
    let woken_record =
        follow_up_step.map(|step| queue_follow_up(record, step));
    let mut changed = woken_record.unwrap_or_else(|| record.clone());
    changed.run.chat.push(message.clone());
    changed
}

fn find_follow_up_step<'run>(
    record: &'run RunRecord,
    message: &ChatMessage,
) -> Option<&'run RunStep> {
    let wakes_the_run = message.author == ChatAuthor::You
        && is_run_finished(record.run.status);
    if !wakes_the_run {
        return None;
    }
    find_last_agent_step(&record.run.steps)
}

fn find_last_agent_step(steps: &[RunStep]) -> Option<&RunStep> {
    let failed_step =
        steps.iter().find(|step| step.status == StepStatus::Failed);
    if failed_step.is_some() {
        return failed_step;
    }
    steps
        .iter()
        .filter(|step| step.started_at.is_some())
        .max_by_key(|step| step.started_at)
}

fn queue_follow_up(
    record: &RunRecord,
    follow_up_step: &RunStep,
) -> RunRecord {
    let step_name = &follow_up_step.name;
    let follow_up = FollowUp {
        answered_user_messages: count_user_messages(&record.run.chat),
    };
    let mut follow_ups = record.follow_ups.clone();
    follow_ups.insert(step_name.clone(), follow_up);

    let mut pinned_steps = record.pinned_steps.clone();
    if let Some(session_holder) = &follow_up_step.runner {
        pinned_steps.insert(step_name.clone(), session_holder.clone());
    }

    let mut steps = Vec::new();
    for step in &record.run.steps {
        if &step.name == step_name {
            steps.push(requeue_step(step));
        } else {
            steps.push(step.clone());
        }
    }
    RunRecord {
        run: reopen_run(&record.run, steps),
        pinned_steps,
        follow_ups,
    }
}

fn count_user_messages(chat: &[ChatMessage]) -> usize {
    chat.iter()
        .filter(|message| message.author == ChatAuthor::You)
        .count()
}
