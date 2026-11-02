use std::time::Duration;

use tokio::time::{Interval, MissedTickBehavior, interval};

pub(crate) fn steady_interval(period: Duration) -> Interval {
    let mut timer = interval(period);
    timer.set_missed_tick_behavior(MissedTickBehavior::Delay);
    timer
}
