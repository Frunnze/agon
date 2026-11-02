use orchestration_node::device_files::DeviceFiles;
use orchestration_node::runner_bridge::place_agents;
use orchestration_node::runner_settings::{
    AgentPlace, ContainerEngineChoice, RunnerSettings, SandboxSettings,
};
use proptest::prelude::*;
use tempfile::TempDir;

use crate::support::test_device::fail;

fn any_place() -> impl Strategy<Value = AgentPlace> {
    prop_oneof![Just(AgentPlace::Container), Just(AgentPlace::LocalProcess)]
}

fn any_container() -> impl Strategy<Value = SandboxSettings> {
    (
        prop_oneof![
            Just(ContainerEngineChoice::Docker),
            Just(ContainerEngineChoice::Podman),
        ],
        "[a-z][a-z0-9-]{0,12}:[a-z0-9]{1,6}",
        proptest::collection::vec("[a-z]{1,8}\\.com", 0..3),
    )
        .prop_map(|(engine, image, allowed_hosts)| {
            SandboxSettings::Container {
                engine,
                image,
                allowed_hosts,
            }
        })
}

fn any_sandbox() -> impl Strategy<Value = SandboxSettings> {
    prop_oneof![Just(SandboxSettings::LocalProcess), any_container()]
}

fn any_settings() -> impl Strategy<Value = RunnerSettings> {
    (
        proptest::collection::vec("[a-z0-9]{1,8}", 0..4),
        1_u32..16,
        any_sandbox(),
        proptest::option::of("file://[a-z/]{1,12}\\{address\\}"),
        proptest::collection::vec("[A-Z_]{1,10}", 0..3),
    )
        .prop_map(|(labels, slot_capacity, sandbox, template, passed)| {
            RunnerSettings {
                labels,
                slot_capacity,
                sandbox,
                clone_url_template: template,
                passed_environment: passed,
            }
        })
}

fn find_place(sandbox: &SandboxSettings) -> AgentPlace {
    match sandbox {
        SandboxSettings::LocalProcess => AgentPlace::LocalProcess,
        SandboxSettings::Container { .. } => AgentPlace::Container,
    }
}

fn without_sandbox(settings: &RunnerSettings) -> RunnerSettings {
    RunnerSettings {
        sandbox: SandboxSettings::LocalProcess,
        ..settings.clone()
    }
}

proptest! {
    #[test]
    fn test_place_agents_property_the_sandbox_follows_the_place(
        settings in any_settings(),
        place in any_place(),
        detected in any_container(),
    ) {
        let placed = place_agents(&settings, place, &detected);

        prop_assert_eq!(find_place(&placed.sandbox), place);
    }

    #[test]
    fn test_place_agents_property_only_the_sandbox_changes(
        settings in any_settings(),
        place in any_place(),
        detected in any_container(),
    ) {
        let placed = place_agents(&settings, place, &detected);

        prop_assert_eq!(without_sandbox(&placed), without_sandbox(&settings));
    }

    #[test]
    fn test_place_agents_property_the_current_place_changes_nothing(
        settings in any_settings(),
        detected in any_container(),
    ) {
        let place = find_place(&settings.sandbox);

        let placed = place_agents(&settings, place, &detected);

        prop_assert_eq!(placed, settings);
    }

    #[test]
    fn test_place_agents_property_local_settings_get_the_detected_container(
        settings in any_settings(),
        detected in any_container(),
    ) {
        let local = RunnerSettings {
            sandbox: SandboxSettings::LocalProcess,
            ..settings
        };

        let placed = place_agents(&local, AgentPlace::Container, &detected);

        prop_assert_eq!(placed.sandbox, detected);
    }

    #[test]
    fn test_place_agents_property_placing_twice_is_placing_once(
        settings in any_settings(),
        first in any_place(),
        second in any_place(),
        detected in any_container(),
    ) {
        let once = place_agents(&settings, second, &detected);
        let between = place_agents(&settings, first, &detected);

        let twice = place_agents(&between, second, &detected);

        prop_assert_eq!(find_place(&twice.sandbox), find_place(&once.sandbox));
        prop_assert_eq!(without_sandbox(&twice), without_sandbox(&once));
    }

    #[test]
    fn test_save_agent_place_property_the_last_saved_place_is_loaded(
        places in proptest::collection::vec(any_place(), 1..6),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let files = DeviceFiles::open(directory.path()).map_err(fail)?;

        for place in &places {
            files.save_agent_place(*place).map_err(fail)?;
        }
        let reopened = DeviceFiles::open(directory.path()).map_err(fail)?;

        prop_assert_eq!(
            reopened.load_agent_place().map_err(fail)?,
            places.last().copied()
        );
    }
}

#[test]
fn nothing_saved_loads_no_place() {
    let Ok(directory) = TempDir::new() else {
        panic!("a folder is made");
    };
    let Ok(files) = DeviceFiles::open(directory.path()) else {
        panic!("the device files open");
    };

    let loaded = files.load_agent_place();

    assert!(matches!(loaded, Ok(None)), "{loaded:?}");
}
