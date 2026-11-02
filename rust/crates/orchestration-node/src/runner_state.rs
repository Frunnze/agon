use std::sync::{Mutex, MutexGuard, PoisonError};

use crate::runner_settings::{AgentPlace, RunnerSettings};

#[derive(Debug)]
pub struct RunnerState {
    settings_in_effect: Mutex<Option<RunnerSettings>>,
    problem: Mutex<Option<String>>,
    chosen_place: Mutex<Option<AgentPlace>>,
}

impl RunnerState {
    #[must_use]
    pub fn new(chosen_place: Option<AgentPlace>) -> Self {
        Self {
            settings_in_effect: Mutex::new(None),
            problem: Mutex::new(None),
            chosen_place: Mutex::new(chosen_place),
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
    pub fn problem(&self) -> Option<String> {
        lock(&self.problem).clone()
    }

    #[cfg(feature = "runner")]
    pub(crate) fn record_problem(&self, problem: Option<String>) {
        *lock(&self.problem) = problem;
    }

    #[must_use]
    pub fn chosen_place(&self) -> Option<AgentPlace> {
        *lock(&self.chosen_place)
    }

    pub(crate) fn remember_chosen_place(&self, place: AgentPlace) {
        *lock(&self.chosen_place) = Some(place);
    }
}

fn lock<Guarded>(guarded: &Mutex<Guarded>) -> MutexGuard<'_, Guarded> {
    guarded.lock().unwrap_or_else(PoisonError::into_inner)
}
