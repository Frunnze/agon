use std::sync::Mutex;

use chrono::{DateTime, TimeDelta, Utc};
use orchestration_server::Clock;

#[derive(Debug)]
pub struct ManualClock {
    current_time: Mutex<DateTime<Utc>>,
}

impl ManualClock {
    pub fn starting_at(start: DateTime<Utc>) -> Self {
        Self {
            current_time: Mutex::new(start),
        }
    }

    pub fn advance(&self, distance: TimeDelta) {
        let mut current_time =
            self.current_time.lock().expect("clock lock is healthy");
        *current_time += distance;
    }
}

impl Clock for ManualClock {
    fn now(&self) -> DateTime<Utc> {
        *self.current_time.lock().expect("clock lock is healthy")
    }
}
