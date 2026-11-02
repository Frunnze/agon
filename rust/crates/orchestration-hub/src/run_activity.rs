use crate::keep_awake::{KeepAwakeError, KeepAwakeGuard};
use crate::slots::{SlotCounter, SlotError};

#[derive(Debug)]
pub enum SleepPrevention {
    NotNeeded,
    Held(KeepAwakeGuard),
    Unavailable(KeepAwakeError),
}

#[derive(Debug)]
pub struct RunActivity {
    slots: SlotCounter,
    sleep_prevention: SleepPrevention,
}

impl RunActivity {
    #[must_use]
    pub fn new(capacity: u32) -> Self {
        Self {
            slots: SlotCounter::new(capacity),
            sleep_prevention: SleepPrevention::NotNeeded,
        }
    }

    pub fn start_run(&mut self) -> Result<(), SlotError> {
        let taken = self.slots.take_slot()?;
        if matches!(self.sleep_prevention, SleepPrevention::NotNeeded) {
            self.sleep_prevention = prevent_sleep();
        }
        self.slots = taken;
        Ok(())
    }

    pub fn finish_run(&mut self) -> Result<(), SlotError> {
        let released = self.slots.release_slot()?;
        self.slots = released;
        if released.busy_slots() == 0 {
            self.sleep_prevention = SleepPrevention::NotNeeded;
        }
        Ok(())
    }

    #[must_use]
    pub fn slots(&self) -> SlotCounter {
        self.slots
    }

    #[must_use]
    pub fn sleep_prevention(&self) -> &SleepPrevention {
        &self.sleep_prevention
    }
}

fn prevent_sleep() -> SleepPrevention {
    match KeepAwakeGuard::acquire() {
        Ok(guard) => SleepPrevention::Held(guard),
        Err(problem) => SleepPrevention::Unavailable(problem),
    }
}
