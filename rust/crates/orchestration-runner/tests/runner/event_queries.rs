use orchestration_api::work::RunEvent;
use orchestration_core::run::{ChatMessage, RunFailure, StepStatus};

pub fn step_statuses(events: &[RunEvent]) -> Vec<(String, StepStatus)> {
    let mut statuses = Vec::new();
    for event in events {
        if let RunEvent::StepStatusChanged { step_name, status } = event {
            statuses.push((step_name.clone(), *status));
        }
    }
    statuses
}

pub fn log_texts(events: &[RunEvent]) -> Vec<String> {
    let mut texts = Vec::new();
    for event in events {
        if let RunEvent::LogAppended { line } = event {
            texts.push(line.text.clone());
        }
    }
    texts
}

pub fn chat_messages(events: &[RunEvent]) -> Vec<ChatMessage> {
    let mut messages = Vec::new();
    for event in events {
        if let RunEvent::ChatAppended { message } = event {
            messages.push(message.clone());
        }
    }
    messages
}

pub fn chat_texts(events: &[RunEvent]) -> Vec<String> {
    let mut texts = Vec::new();
    for message in chat_messages(events) {
        texts.push(message.text);
    }
    texts
}

pub fn sessions(events: &[RunEvent]) -> Vec<String> {
    let mut started_sessions = Vec::new();
    for event in events {
        if let RunEvent::SessionStarted { session } = event {
            started_sessions.push(session.clone());
        }
    }
    started_sessions
}

pub fn branches(events: &[RunEvent]) -> Vec<String> {
    let mut created_branches = Vec::new();
    for event in events {
        if let RunEvent::WorktreeCreated { branch } = event {
            created_branches.push(branch.clone());
        }
    }
    created_branches
}

pub fn failures(events: &[RunEvent]) -> Vec<RunFailure> {
    let mut reported_failures = Vec::new();
    for event in events {
        if let RunEvent::Failed { failure } = event {
            reported_failures.push(failure.clone());
        }
    }
    reported_failures
}

pub fn step_results(events: &[RunEvent]) -> Vec<(String, String)> {
    let mut results = Vec::new();
    for event in events {
        if let RunEvent::StepResultRecorded { step_name, result } = event {
            results.push((step_name.clone(), result.clone()));
        }
    }
    results
}

pub fn has_status(events: &[RunEvent], wanted: StepStatus) -> bool {
    let statuses = step_statuses(events);
    statuses
        .iter()
        .any(|(_step_name, status)| *status == wanted)
}
