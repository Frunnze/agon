use std::collections::BTreeSet;
use std::fs;

use orchestration_core::agent_place::AgentPlace;
use orchestration_node::device_files::DeviceFiles;
use orchestration_node::place_offers::{
    PlaceOffer, find_blocking_problem, normalize_offers,
};
use orchestration_node::runner_bridge::{
    ImageProbeOutcome, check_offers, find_settings_place, offer_sandboxes,
};
use orchestration_node::runner_settings::{
    ContainerEngineChoice, RunnerSettings, SandboxSettings,
};
use proptest::collection::vec;
use proptest::prelude::*;
use tempfile::TempDir;

use crate::support::test_device::fail;

const OLDER_PLACE_FILE_NAME: &str = "agent-place.json";
const MAXIMUM_OFFERS: usize = 4;

fn any_place() -> impl Strategy<Value = AgentPlace> {
    prop_oneof![Just(AgentPlace::Container), Just(AgentPlace::LocalProcess)]
}

fn any_offers() -> impl Strategy<Value = Vec<AgentPlace>> {
    vec(any_place(), 1..MAXIMUM_OFFERS)
}

fn any_container() -> impl Strategy<Value = SandboxSettings> {
    (
        prop_oneof![
            Just(ContainerEngineChoice::Docker),
            Just(ContainerEngineChoice::Podman),
        ],
        "[a-z][a-z0-9-]{0,12}:[a-z0-9]{1,6}",
        vec("[a-z]{1,8}\\.com", 0..3),
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
        vec("[a-z0-9]{1,8}", 0..4),
        1_u32..16,
        any_sandbox(),
        proptest::option::of("file://[a-z/]{1,12}\\{address\\}"),
        vec("[A-Z_]{1,10}", 0..3),
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

fn any_probe_outcome() -> impl Strategy<Value = ImageProbeOutcome> {
    prop_oneof![
        Just(ImageProbeOutcome::Present),
        Just(ImageProbeOutcome::Missing),
        Just(ImageProbeOutcome::EngineStopped),
        "[a-z ]{1,12}".prop_map(ImageProbeOutcome::EngineFailed),
    ]
}

fn any_place_offer() -> impl Strategy<Value = PlaceOffer> {
    (any_place(), proptest::option::of("[A-Za-z ]{1,20}"))
        .prop_map(|(place, problem)| PlaceOffer { place, problem })
}

fn place_of(sandbox: &SandboxSettings) -> AgentPlace {
    match sandbox {
        SandboxSettings::LocalProcess => AgentPlace::LocalProcess,
        SandboxSettings::Container { .. } => AgentPlace::Container,
    }
}

proptest! {
    #[test]
    fn test_offer_sandboxes_property_one_sandbox_per_offer_at_its_place(
        settings in any_settings(),
        offers in any_offers(),
        detected in any_container(),
    ) {
        let sandboxes = offer_sandboxes(&settings, &offers, &detected);

        let places: Vec<AgentPlace> = sandboxes.iter().map(place_of).collect();
        prop_assert_eq!(places, offers);
    }

    #[test]
    fn test_offer_sandboxes_property_a_given_container_is_kept(
        settings in any_settings(),
        given in any_container(),
        detected in any_container(),
    ) {
        let container_settings = RunnerSettings {
            sandbox: given.clone(),
            ..settings
        };
        let offers = [AgentPlace::Container];

        let sandboxes =
            offer_sandboxes(&container_settings, &offers, &detected);

        prop_assert_eq!(sandboxes, vec![given]);
    }

    #[test]
    fn test_offer_sandboxes_property_local_settings_get_the_detected_one(
        settings in any_settings(),
        detected in any_container(),
    ) {
        let local_settings = RunnerSettings {
            sandbox: SandboxSettings::LocalProcess,
            ..settings
        };
        let offers = [AgentPlace::Container];

        let sandboxes = offer_sandboxes(&local_settings, &offers, &detected);

        prop_assert_eq!(sandboxes, vec![detected]);
    }

    #[test]
    fn test_find_settings_place_property_follows_the_sandbox_kind(
        sandbox in any_sandbox(),
    ) {
        prop_assert_eq!(find_settings_place(&sandbox), place_of(&sandbox));
    }

    #[test]
    fn test_check_offers_property_only_containers_can_have_problems(
        sandboxes in vec(any_sandbox(), 0..MAXIMUM_OFFERS),
        outcome in any_probe_outcome(),
    ) {
        let probe = |_program: &str, _image: &str| outcome.clone();

        let checks = check_offers(&sandboxes, probe);

        prop_assert_eq!(checks.len(), sandboxes.len());
        let is_ready = outcome == ImageProbeOutcome::Present;
        for (check, sandbox) in checks.iter().zip(&sandboxes) {
            prop_assert_eq!(check.place, place_of(sandbox));
            let can_fail = check.place == AgentPlace::Container;
            prop_assert_eq!(check.problem.is_some(), can_fail && !is_ready);
        }
    }

    #[test]
    fn test_find_blocking_problem_property_only_when_nothing_can_run(
        offers in vec(any_place_offer(), 0..MAXIMUM_OFFERS),
    ) {
        let blocking = find_blocking_problem(&offers);

        let nothing_runs = !offers.is_empty()
            && offers.iter().all(|offer| offer.problem.is_some());
        let expected = if nothing_runs {
            offers[0].problem.clone()
        } else {
            None
        };
        prop_assert_eq!(blocking, expected);
    }

    #[test]
    fn test_normalize_offers_property_sorted_once_each_same_places(
        offers in vec(any_place(), 0..6),
    ) {
        let normalized = normalize_offers(&offers);

        let distinct: BTreeSet<AgentPlace> = offers.iter().copied().collect();
        let expected: Vec<AgentPlace> = distinct.into_iter().collect();
        prop_assert_eq!(normalized, expected);
    }

    #[test]
    fn test_save_agent_offers_property_the_last_saved_offers_are_loaded(
        choices in vec(any_offers(), 1..5),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let files = DeviceFiles::open(directory.path()).map_err(fail)?;

        for offers in &choices {
            files.save_agent_offers(offers).map_err(fail)?;
        }
        let reopened = DeviceFiles::open(directory.path()).map_err(fail)?;

        prop_assert_eq!(
            reopened.load_agent_offers().map_err(fail)?,
            choices.last().cloned()
        );
    }

    #[test]
    fn test_load_agent_offers_property_an_older_single_place_is_one_offer(
        place in any_place(),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let older_choice = serde_json::to_string(&place).map_err(fail)?;
        let older_file = directory.path().join(OLDER_PLACE_FILE_NAME);
        fs::write(older_file, older_choice).map_err(fail)?;

        let files = DeviceFiles::open(directory.path()).map_err(fail)?;

        prop_assert_eq!(
            files.load_agent_offers().map_err(fail)?,
            Some(vec![place])
        );
    }
}

#[test]
fn nothing_saved_loads_no_offers() {
    let Ok(directory) = TempDir::new() else {
        panic!("a folder is made");
    };
    let Ok(files) = DeviceFiles::open(directory.path()) else {
        panic!("the device files open");
    };

    let loaded = files.load_agent_offers();

    assert!(matches!(loaded, Ok(None)), "{loaded:?}");
}
