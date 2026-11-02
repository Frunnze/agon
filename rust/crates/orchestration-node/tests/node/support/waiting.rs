use std::thread;
use std::time::{Duration, Instant};

const POLL_PAUSE: Duration = Duration::from_millis(100);

pub fn wait_for<Found>(
    limit: Duration,
    description: &str,
    mut look: impl FnMut() -> Result<Option<Found>, String>,
) -> Result<Found, String> {
    let deadline = Instant::now() + limit;
    loop {
        if let Some(found) = look()? {
            return Ok(found);
        }
        if Instant::now() >= deadline {
            return Err(format!("timed out waiting for {description}"));
        }
        thread::sleep(POLL_PAUSE);
    }
}
