use thiserror::Error;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct SlotCounter {
    capacity: u32,
    busy: u32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Error)]
pub enum SlotError {
    #[error("every slot is busy")]
    NoFreeSlot,
    #[error("no slot is busy")]
    NoBusySlot,
}

impl SlotCounter {
    #[must_use]
    pub fn new(capacity: u32) -> Self {
        Self { capacity, busy: 0 }
    }

    pub fn take_slot(self) -> Result<Self, SlotError> {
        if self.busy >= self.capacity {
            return Err(SlotError::NoFreeSlot);
        }
        Ok(Self {
            busy: self.busy + 1,
            ..self
        })
    }

    pub fn release_slot(self) -> Result<Self, SlotError> {
        if self.busy == 0 {
            return Err(SlotError::NoBusySlot);
        }
        Ok(Self {
            busy: self.busy - 1,
            ..self
        })
    }

    #[must_use]
    pub fn capacity(self) -> u32 {
        self.capacity
    }

    #[must_use]
    pub fn busy_slots(self) -> u32 {
        self.busy
    }
}
