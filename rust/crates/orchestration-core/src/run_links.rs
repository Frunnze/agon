use chrono::{DateTime, Utc};

use crate::device::RunnerLink;
use crate::run::Run;

#[must_use]
pub fn record_link_change(
    run: &Run,
    link: RunnerLink,
    at: DateTime<Utc>,
) -> Run {
    let was_connected = is_connected(run.link);
    let link_lost_at = match link {
        RunnerLink::Unreachable if was_connected => Some(at),
        RunnerLink::Unreachable => run.link_lost_at,
        RunnerLink::Direct | RunnerLink::Relay | RunnerLink::LocalNetwork => {
            None
        }
    };
    Run {
        link,
        link_lost_at,
        ..run.clone()
    }
}

#[must_use]
pub fn is_connected(link: RunnerLink) -> bool {
    link != RunnerLink::Unreachable
}
