use std::path::PathBuf;
use std::time::Duration;

pub const EVENTS_LONG_POLL_TIMEOUT: Duration = Duration::from_secs(25);

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ServerSettings {
    pub data_directory: PathBuf,
    pub public_address: String,
    pub long_poll_timeout: Duration,
}
