use std::sync::{Mutex, MutexGuard, PoisonError};

use orchestration_core::agent_place::AgentPlace;

use crate::place_offers::{PlaceOffer, find_blocking_problem};
use crate::runner_settings::RunnerSettings;

#[derive(Debug)]
pub struct RunnerState {
    settings_in_effect: Mutex<Option<RunnerSettings>>,
    checked_offers: Mutex<Vec<PlaceOffer>>,
    chosen_offers: Mutex<Option<Vec<AgentPlace>>>,
}

impl RunnerState {
    #[must_use]
    pub fn new(chosen_offers: Option<Vec<AgentPlace>>) -> Self {
        Self {
            settings_in_effect: Mutex::new(None),
            checked_offers: Mutex::new(Vec::new()),
            chosen_offers: Mutex::new(chosen_offers),
        }
    }

    #[must_use]
    pub fn settings_in_effect(&self) -> Option<RunnerSettings> {
        lock(&self.settings_in_effect).clone()
    }

    #[cfg(feature = "runner")]
    pub(crate) fn record_settings(&self, settings: RunnerSettings) {
        *lock(&self.settings_in_effect) = Some(settings);
    }

    #[must_use]
    pub fn checked_offers(&self) -> Vec<PlaceOffer> {
        lock(&self.checked_offers).clone()
    }

    #[cfg(feature = "runner")]
    pub(crate) fn record_checked_offers(&self, offers: Vec<PlaceOffer>) {
        *lock(&self.checked_offers) = offers;
    }

    #[must_use]
    pub fn problem(&self) -> Option<String> {
        find_blocking_problem(&lock(&self.checked_offers))
    }

    #[must_use]
    pub fn chosen_offers(&self) -> Option<Vec<AgentPlace>> {
        lock(&self.chosen_offers).clone()
    }

    pub(crate) fn remember_chosen_offers(&self, offers: Vec<AgentPlace>) {
        *lock(&self.chosen_offers) = Some(offers);
    }
}

fn lock<Guarded>(guarded: &Mutex<Guarded>) -> MutexGuard<'_, Guarded> {
    guarded.lock().unwrap_or_else(PoisonError::into_inner)
}
