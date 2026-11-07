use std::fs;
use std::path::PathBuf;

use chrono::DateTime;
use orchestration_core::run::{Run, RunStep};
use serde::{Deserialize, Serialize};

use crate::live_run_event_plans::{CaseDice, PostedEvent, plan_case};
use crate::live_run_event_replay::replay_posted_events;
use crate::test_client::{START_TIME_SECONDS, block_on};

pub const WRITE_TABLE_VARIABLE: &str = "WRITE_SHARED_LIVE_RUN_CASES";
const TABLE_PATH: &str = "tests/fixtures/live_run_event_cases.json";
const CASE_COUNT: u64 = 64;
const FIRST_CASE_SEED: u64 = 70_331;

#[derive(Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SharedPostedEvent {
    #[serde(flatten)]
    pub posted: PostedEvent,
    pub is_accepted: bool,
}

#[derive(Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SharedLiveRunCase {
    pub step_names: Vec<String>,
    pub initial_run: Run,
    pub events: Vec<SharedPostedEvent>,
    pub expected_run: Run,
}

#[derive(Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SharedLiveRunTable {
    pub cases: Vec<SharedLiveRunCase>,
}

fn table_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(TABLE_PATH)
}

pub fn read_shared_table() -> SharedLiveRunTable {
    let table_text =
        fs::read_to_string(table_path()).expect("the shared table exists");
    serde_json::from_str(&table_text).expect("the shared table decodes")
}

pub fn write_shared_table() {
    let start = DateTime::from_timestamp(START_TIME_SECONDS, 0)
        .expect("the start time is valid");
    let mut cases = Vec::new();
    for case_number in 0..CASE_COUNT {
        let mut dice = CaseDice::seeded(FIRST_CASE_SEED + case_number);
        let planned = plan_case(&mut dice, start);
        let replayed = block_on(replay_posted_events(
            &planned.step_names,
            &planned.events,
        ));
        let mut events = Vec::new();
        for (posted, is_accepted) in
            planned.events.into_iter().zip(replayed.acceptances)
        {
            events.push(SharedPostedEvent {
                posted,
                is_accepted,
            });
        }
        cases.push(SharedLiveRunCase {
            step_names: planned.step_names,
            initial_run: replayed.initial_run,
            events,
            expected_run: replayed.expected_run,
        });
    }
    let table = SharedLiveRunTable { cases };
    let mut table_text =
        serde_json::to_string_pretty(&table).expect("the table encodes");
    table_text.push('\n');
    fs::write(table_path(), table_text).expect("the shared table is written");
}

pub fn adopt_table_identity(replayed: &Run, table_run: &Run) -> Run {
    let mut steps = Vec::new();
    for (step, table_step) in replayed.steps.iter().zip(&table_run.steps) {
        steps.push(RunStep {
            agent_id: table_step.agent_id,
            ..step.clone()
        });
    }
    Run {
        id: table_run.id,
        task_id: table_run.task_id,
        steps,
        ..replayed.clone()
    }
}
