use std::collections::BTreeSet;

use orchestration_core::agent_place::AgentPlace;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlaceOffer {
    pub place: AgentPlace,
    pub problem: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
pub(crate) enum StoredOffers {
    Offers(Vec<AgentPlace>),
    OlderSingleChoice(AgentPlace),
}

impl StoredOffers {
    pub(crate) fn into_offers(self) -> Vec<AgentPlace> {
        match self {
            Self::Offers(offers) => offers,
            Self::OlderSingleChoice(place) => vec![place],
        }
    }
}

#[must_use]
pub fn normalize_offers(offers: &[AgentPlace]) -> Vec<AgentPlace> {
    let distinct_offers: BTreeSet<AgentPlace> =
        offers.iter().copied().collect();
    distinct_offers.into_iter().collect()
}

#[must_use]
pub fn find_blocking_problem(offers: &[PlaceOffer]) -> Option<String> {
    let first_offer = offers.first()?;
    let nothing_runs = offers.iter().all(|offer| offer.problem.is_some());
    if !nothing_runs {
        return None;
    }
    first_offer.problem.clone()
}
