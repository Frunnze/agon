use chrono::{DateTime, TimeDelta, Utc};
use orchestration_api::work::RunEvent;
use orchestration_core::run::{
    ChatAuthor, ChatMessage, LogLine, RunFailure, StepStatus,
};
use serde::{Deserialize, Serialize};

const STEP_NAMES: [&str; 3] = ["plan", "build-2", "review"];
const UNKNOWN_STEP_NAME: &str = "no such step";
const LARGEST_EVENT_COUNT: usize = 12;
const LARGEST_PAUSE_SECONDS: usize = 3;
const STATUSES: [StepStatus; 7] = [
    StepStatus::Waiting,
    StepStatus::Running,
    StepStatus::WaitingForApproval,
    StepStatus::WaitingForPerson,
    StepStatus::Done,
    StepStatus::Failed,
    StepStatus::Skipped,
];
const AUTHORS: [ChatAuthor; 4] = [
    ChatAuthor::You,
    ChatAuthor::You,
    ChatAuthor::Agent,
    ChatAuthor::Tool,
];
const EVENT_KINDS: [EventKind; 11] = [
    EventKind::StatusChange,
    EventKind::StatusChange,
    EventKind::StatusChange,
    EventKind::Log,
    EventKind::Chat,
    EventKind::Chat,
    EventKind::Session,
    EventKind::Worktree,
    EventKind::Failure,
    EventKind::Result,
    EventKind::Finish,
];

#[derive(Clone, Copy, Debug)]
enum EventKind {
    StatusChange,
    Log,
    Chat,
    Session,
    Worktree,
    Failure,
    Result,
    Finish,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PostedEvent {
    pub posted_at: DateTime<Utc>,
    pub event: RunEvent,
}

#[derive(Debug)]
pub struct PlannedCase {
    pub step_names: Vec<String>,
    pub events: Vec<PostedEvent>,
}

#[derive(Debug)]
pub struct CaseDice {
    state: u64,
}

impl CaseDice {
    pub fn seeded(seed: u64) -> Self {
        Self { state: seed | 1 }
    }

    fn roll(&mut self, sides: usize) -> usize {
        self.state ^= self.state << 13;
        self.state ^= self.state >> 7;
        self.state ^= self.state << 17;
        let sides = u64::try_from(sides).expect("sides fit in 64 bits");
        usize::try_from(self.state % sides).expect("a roll fits in usize")
    }

    fn flip(&mut self) -> bool {
        self.roll(2) == 0
    }
}

fn pick_step_name(dice: &mut CaseDice, step_names: &[String]) -> String {
    let position = dice.roll(step_names.len() + 1);
    step_names
        .get(position)
        .cloned()
        .unwrap_or_else(|| UNKNOWN_STEP_NAME.to_owned())
}

fn plan_event(
    dice: &mut CaseDice,
    step_names: &[String],
    position: usize,
    at: DateTime<Utc>,
) -> RunEvent {
    let kind = EVENT_KINDS[dice.roll(EVENT_KINDS.len())];
    match kind {
        EventKind::StatusChange => RunEvent::StepStatusChanged {
            step_name: pick_step_name(dice, step_names),
            status: STATUSES[dice.roll(STATUSES.len())],
        },
        EventKind::Log => RunEvent::LogAppended {
            line: LogLine {
                at,
                step_name: pick_step_name(dice, step_names),
                text: format!("line {position} café"),
                is_error: dice.flip(),
            },
        },
        EventKind::Chat => RunEvent::ChatAppended {
            message: ChatMessage {
                at,
                author: AUTHORS[dice.roll(AUTHORS.len())],
                text: format!("message {position}"),
                is_error: dice.flip(),
                waiting_to_send: dice.flip(),
            },
        },
        EventKind::Session => RunEvent::SessionStarted {
            session: format!("session-{position}"),
        },
        EventKind::Worktree => RunEvent::WorktreeCreated {
            branch: format!("agent/branch-{position}"),
        },
        EventKind::Failure => RunEvent::Failed {
            failure: RunFailure {
                step_name: pick_step_name(dice, step_names),
                runner: None,
                reason: format!("reason {position}"),
                retry_runs_on_same_runner: dice.flip(),
            },
        },
        EventKind::Result => RunEvent::StepResultRecorded {
            step_name: pick_step_name(dice, step_names),
            result: format!("result {position}"),
            outcome: dice.flip().then(|| format!("outcome {position}")),
        },
        EventKind::Finish => RunEvent::Finished,
    }
}

pub fn plan_case(dice: &mut CaseDice, start: DateTime<Utc>) -> PlannedCase {
    let step_count = 1 + dice.roll(STEP_NAMES.len());
    let step_names: Vec<String> = STEP_NAMES[..step_count]
        .iter()
        .map(|name| (*name).to_owned())
        .collect();
    let event_count = 1 + dice.roll(LARGEST_EVENT_COUNT);

    let mut posted_at = start;
    let mut events = Vec::new();
    for position in 0..event_count {
        let pause_seconds = dice.roll(LARGEST_PAUSE_SECONDS);
        let pause_seconds =
            i64::try_from(pause_seconds).expect("a pause fits in i64");
        posted_at += TimeDelta::seconds(pause_seconds);
        let event = plan_event(dice, &step_names, position, posted_at);
        events.push(PostedEvent { posted_at, event });
    }

    PlannedCase { step_names, events }
}
