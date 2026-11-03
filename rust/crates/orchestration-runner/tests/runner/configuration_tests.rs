use std::collections::BTreeMap;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use orchestration_core::agent_place::find_sandbox_place;
use orchestration_core::device::{RunnerLink, SandboxKind};
use orchestration_core::identifiers::TaskId;
use orchestration_hub::clone_source::CloneSource;
use orchestration_hub::slots::SlotCounter;
use orchestration_runner::agent_run_executor::AgentRunExecutor;
use orchestration_runner::agent_sandbox::AgentSandbox;
use orchestration_runner::branch_pusher::GitBranchPusher;
use orchestration_runner::heartbeat::describe_heartbeat;
use orchestration_runner::runner_configuration::{
    ConfigurationProblem, RunnerConfiguration, RunnerIntervals, WorktreeRoots,
    validate_configuration,
};
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::fake_agent::test_container;
use crate::fake_server::FakeServer;

const CACHE_ROOT: &str = "/runner/cache";
const WORKTREES_ROOT: &str = "/runner/worktrees";

fn any_interval() -> impl Strategy<Value = Duration> {
    (1_u64..100_000).prop_map(Duration::from_millis)
}

fn any_intervals() -> impl Strategy<Value = RunnerIntervals> {
    (any_interval(), any_interval(), any_interval()).prop_map(
        |(heartbeat, claim, cancellation_check)| RunnerIntervals {
            heartbeat,
            claim,
            cancellation_check,
        },
    )
}

fn any_sandbox_kind() -> impl Strategy<Value = SandboxKind> {
    prop_oneof![
        Just(SandboxKind::LocalProcess),
        Just(SandboxKind::Container),
        Just(SandboxKind::MicroVirtualMachine),
    ]
}

fn any_sandbox() -> impl Strategy<Value = AgentSandbox> {
    (any_sandbox_kind(), vec("[a-z]{1,8}\\.[a-z]{2,3}", 0..3)).prop_map(
        |(kind, allowed_hosts)| AgentSandbox {
            kind,
            container: test_container(),
            allowed_hosts,
            environment: BTreeMap::new(),
        },
    )
}

fn any_configuration() -> impl Strategy<Value = RunnerConfiguration> {
    (
        vec("[a-z]{1,8}", 0..4),
        1_u32..16,
        vec(any_sandbox(), 1..3),
        any_intervals(),
    )
        .prop_map(|(labels, slot_capacity, sandboxes, intervals)| {
            RunnerConfiguration {
                labels,
                slot_capacity,
                link: RunnerLink::Relay,
                sandboxes,
                worktree_roots: WorktreeRoots {
                    cache_root: PathBuf::from(CACHE_ROOT),
                    worktrees_root: PathBuf::from(WORKTREES_ROOT),
                },
                clone_source: CloneSource::standard(),
                intervals,
            }
        })
}

fn with_zero_interval(
    configuration: &RunnerConfiguration,
    which: usize,
) -> RunnerConfiguration {
    let intervals = configuration.intervals;
    let changed_intervals = match which {
        0 => RunnerIntervals {
            heartbeat: Duration::ZERO,
            ..intervals
        },
        1 => RunnerIntervals {
            claim: Duration::ZERO,
            ..intervals
        },
        _ => RunnerIntervals {
            cancellation_check: Duration::ZERO,
            ..intervals
        },
    };
    RunnerConfiguration {
        intervals: changed_intervals,
        ..configuration.clone()
    }
}

fn take_slots(capacity: u32, busy: u32) -> SlotCounter {
    let mut slots = SlotCounter::new(capacity);
    for _ in 0..busy.min(capacity) {
        slots = slots.take_slot().unwrap_or(slots);
    }
    slots
}

proptest! {
    #[test]
    fn test_validate_configuration_property_accepts_complete_settings(
        configuration in any_configuration(),
    ) {
        prop_assert_eq!(validate_configuration(&configuration), Ok(()));
    }

    #[test]
    fn test_validate_configuration_property_rejects_any_zero_interval(
        configuration in any_configuration(),
        which in 0_usize..3,
    ) {
        let changed = with_zero_interval(&configuration, which);

        let validated = validate_configuration(&changed);

        let is_zero_interval =
            matches!(validated, Err(ConfigurationProblem::ZeroInterval(_)));
        prop_assert!(is_zero_interval);
    }

    #[test]
    fn test_validate_configuration_property_rejects_a_runner_without_slots(
        configuration in any_configuration(),
    ) {
        let changed = RunnerConfiguration {
            slot_capacity: 0,
            ..configuration
        };

        let validated = validate_configuration(&changed);

        prop_assert_eq!(validated, Err(ConfigurationProblem::NoSlots));
    }

    #[test]
    fn test_validate_configuration_property_rejects_a_runner_offering_nothing(
        configuration in any_configuration(),
    ) {
        let changed = RunnerConfiguration {
            sandboxes: Vec::new(),
            ..configuration
        };

        let validated = validate_configuration(&changed);

        prop_assert_eq!(validated, Err(ConfigurationProblem::NoSandbox));
    }

    #[test]
    fn test_validate_configuration_property_rejects_relative_folders(
        configuration in any_configuration(),
        relative_folder in "[a-z]{1,8}(/[a-z]{1,8}){0,2}",
        is_cache_root in any::<bool>(),
    ) {
        let roots = configuration.worktree_roots.clone();
        let changed_roots = if is_cache_root {
            WorktreeRoots {
                cache_root: PathBuf::from(&relative_folder),
                ..roots
            }
        } else {
            WorktreeRoots {
                worktrees_root: PathBuf::from(&relative_folder),
                ..roots
            }
        };
        let changed = RunnerConfiguration {
            worktree_roots: changed_roots,
            ..configuration
        };

        let validated = validate_configuration(&changed);

        let expected = ConfigurationProblem::RelativeFolder(
            PathBuf::from(relative_folder),
        );
        prop_assert_eq!(validated, Err(expected));
    }

    #[test]
    fn test_new_property_rejects_exactly_what_validation_rejects(
        configuration in any_configuration(),
        slot_capacity in 0_u32..3,
    ) {
        let changed = RunnerConfiguration {
            slot_capacity,
            ..configuration
        };
        let server = Arc::new(FakeServer::with_queue(Vec::new()));

        let created = AgentRunExecutor::new(server, GitBranchPusher, &changed);

        let validated = validate_configuration(&changed);
        prop_assert_eq!(created.err(), validated.err());
    }

    #[test]
    fn test_standard_property_passes_validation(
        configuration in any_configuration(),
    ) {
        let standard = RunnerConfiguration {
            intervals: RunnerIntervals::standard(),
            ..configuration
        };

        prop_assert_eq!(validate_configuration(&standard), Ok(()));
    }

    #[test]
    fn test_describe_heartbeat_property_reports_settings_and_slots(
        configuration in any_configuration(),
        busy in 0_u32..16,
        cached_repositories in proptest::collection::vec("[a-z./]{1,20}", 0..4),
        held_numbers in proptest::collection::vec(any::<u128>(), 0..4),
    ) {
        let slots = take_slots(configuration.slot_capacity, busy);
        let held_tasks: Vec<TaskId> = held_numbers
            .iter()
            .map(|number| TaskId(Uuid::from_u128(*number)))
            .collect();

        let heartbeat = describe_heartbeat(
            &configuration,
            slots,
            cached_repositories.clone(),
            held_tasks.clone(),
        );

        prop_assert_eq!(&heartbeat.labels, &configuration.labels);
        prop_assert_eq!(heartbeat.slots_total, configuration.slot_capacity);
        prop_assert_eq!(heartbeat.slots_busy, slots.busy_slots());
        prop_assert!(heartbeat.slots_busy <= heartbeat.slots_total);
        prop_assert_eq!(heartbeat.link, configuration.link);
        let mut offers = Vec::new();
        let mut allowed_hosts = Vec::new();
        for sandbox in &configuration.sandboxes {
            offers.extend(find_sandbox_place(sandbox.kind));
            allowed_hosts.extend(sandbox.allowed_hosts.iter().cloned());
        }
        prop_assert_eq!(&heartbeat.offers, &offers);
        prop_assert_eq!(&heartbeat.allowed_hosts, &allowed_hosts);
        prop_assert_eq!(heartbeat.cached_repositories, cached_repositories);
        prop_assert_eq!(heartbeat.held_tasks, held_tasks);
    }
}
