use std::collections::BTreeSet;

use orchestration_node::runner_bridge::{
    HostFacts, detect_container_sandbox, detect_runner_settings,
    read_host_facts,
};
use orchestration_node::runner_settings::{
    ContainerEngineChoice, SandboxSettings,
};
use proptest::prelude::*;

const PROBED_PROGRAMS: [&str; 3] = ["xcodebuild", "docker", "podman"];

fn any_host_facts() -> impl Strategy<Value = HostFacts> {
    (
        prop_oneof![
            Just("macos".to_owned()),
            Just("linux".to_owned()),
            Just("windows".to_owned()),
            "[a-z]{1,8}",
        ],
        prop_oneof![
            Just("aarch64".to_owned()),
            Just("x86_64".to_owned()),
            "[a-z0-9_]{1,8}",
        ],
        0_usize..256,
        proptest::sample::subsequence(PROBED_PROGRAMS.to_vec(), 0..=3),
    )
        .prop_map(
            |(operating_system, architecture, processors, found)| HostFacts {
                operating_system,
                architecture,
                processor_count: processors,
                programs_found: found.into_iter().map(str::to_owned).collect(),
            },
        )
}

fn has_program(facts: &HostFacts, program: &str) -> bool {
    facts.programs_found.contains(program)
}

#[test]
fn this_machine_gives_usable_settings() {
    let facts = read_host_facts();

    let settings = detect_runner_settings(&facts);

    assert!(settings.slot_capacity >= 1);
    assert!(settings.labels.len() >= 2, "{:?}", settings.labels);
    assert_eq!(settings.clone_url_template, None);
}

proptest! {
    #[test]
    fn test_detect_runner_settings_property_uses_half_the_cores(
        facts in any_host_facts(),
    ) {
        let settings = detect_runner_settings(&facts);

        let half_cores = facts.processor_count / 2;
        let half = u32::try_from(half_cores).unwrap_or(u32::MAX);
        prop_assert_eq!(settings.slot_capacity, half.max(1));
    }

    #[test]
    fn test_detect_runner_settings_property_labels_name_the_host(
        facts in any_host_facts(),
    ) {
        let settings = detect_runner_settings(&facts);

        let labels: BTreeSet<&str> =
            settings.labels.iter().map(String::as_str).collect();
        prop_assert_eq!(labels.len(), settings.labels.len());
        prop_assert_eq!(
            labels.contains("xcode"),
            has_program(&facts, "xcodebuild")
        );
        let names_the_system = match facts.operating_system.as_str() {
            "macos" => labels.contains("mac"),
            other => labels.contains(other),
        };
        let names_the_processor = match facts.architecture.as_str() {
            "aarch64" => labels.contains("arm64"),
            "x86_64" => labels.contains("x64"),
            other => labels.contains(other),
        };
        prop_assert!(names_the_system && names_the_processor, "{:?}", labels);
    }

    #[test]
    fn test_detect_runner_settings_property_starts_on_this_computer(
        facts in any_host_facts(),
    ) {
        let settings = detect_runner_settings(&facts);

        prop_assert_eq!(settings.sandbox, SandboxSettings::LocalProcess);
    }

    #[test]
    fn test_detect_container_sandbox_property_is_always_a_container(
        facts in any_host_facts(),
    ) {
        let sandbox = detect_container_sandbox(&facts);

        let SandboxSettings::Container { engine, image, allowed_hosts } =
            sandbox
        else {
            return Err(TestCaseError::fail("a container is detected"));
        };
        let only_podman = has_program(&facts, "podman")
            && !has_program(&facts, "docker");
        let expected_engine = if only_podman {
            ContainerEngineChoice::Podman
        } else {
            ContainerEngineChoice::Docker
        };
        prop_assert_eq!(engine, expected_engine);
        prop_assert!(!image.is_empty());
        prop_assert!(!allowed_hosts.is_empty());
    }

}
