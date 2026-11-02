use std::path::{Path, PathBuf};
use std::time::Duration;

use orchestration_core::device::RunnerLink;
use orchestration_hub::clone_source::CloneSource;
use thiserror::Error;

use crate::agent_sandbox::AgentSandbox;

const STANDARD_HEARTBEAT_INTERVAL: Duration = Duration::from_secs(15);
const STANDARD_CLAIM_INTERVAL: Duration = Duration::from_secs(5);
const STANDARD_CANCELLATION_CHECK_INTERVAL: Duration = Duration::from_secs(2);
const HEARTBEAT_INTERVAL_NAME: &str = "heartbeat";
const CLAIM_INTERVAL_NAME: &str = "claim";
const CANCELLATION_CHECK_INTERVAL_NAME: &str = "cancellation check";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct RunnerIntervals {
    pub heartbeat: Duration,
    pub claim: Duration,
    pub cancellation_check: Duration,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct WorktreeRoots {
    pub cache_root: PathBuf,
    pub worktrees_root: PathBuf,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RunnerConfiguration {
    pub labels: Vec<String>,
    pub slot_capacity: u32,
    pub link: RunnerLink,
    pub sandbox: AgentSandbox,
    pub worktree_roots: WorktreeRoots,
    pub clone_source: CloneSource,
    pub intervals: RunnerIntervals,
}

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum ConfigurationProblem {
    #[error("the runner needs at least one slot")]
    NoSlots,
    #[error("the {0} interval must be longer than zero")]
    ZeroInterval(&'static str),
    #[error("the folder {0:?} is not an absolute path")]
    RelativeFolder(PathBuf),
}

impl RunnerIntervals {
    #[must_use]
    pub fn standard() -> Self {
        Self {
            heartbeat: STANDARD_HEARTBEAT_INTERVAL,
            claim: STANDARD_CLAIM_INTERVAL,
            cancellation_check: STANDARD_CANCELLATION_CHECK_INTERVAL,
        }
    }
}

pub fn validate_configuration(
    configuration: &RunnerConfiguration,
) -> Result<(), ConfigurationProblem> {
    if configuration.slot_capacity == 0 {
        return Err(ConfigurationProblem::NoSlots);
    }
    validate_intervals(&configuration.intervals)?;

    let roots = &configuration.worktree_roots;
    ensure_absolute_folder(&roots.cache_root)?;
    ensure_absolute_folder(&roots.worktrees_root)
}

fn validate_intervals(
    intervals: &RunnerIntervals,
) -> Result<(), ConfigurationProblem> {
    let named_intervals = [
        (HEARTBEAT_INTERVAL_NAME, intervals.heartbeat),
        (CLAIM_INTERVAL_NAME, intervals.claim),
        (
            CANCELLATION_CHECK_INTERVAL_NAME,
            intervals.cancellation_check,
        ),
    ];
    for (name, interval) in named_intervals {
        if interval.is_zero() {
            return Err(ConfigurationProblem::ZeroInterval(name));
        }
    }
    Ok(())
}

fn ensure_absolute_folder(folder: &Path) -> Result<(), ConfigurationProblem> {
    if !folder.is_absolute() {
        let folder = folder.to_path_buf();
        return Err(ConfigurationProblem::RelativeFolder(folder));
    }
    Ok(())
}
