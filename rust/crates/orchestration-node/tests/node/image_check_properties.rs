use std::cell::RefCell;

use orchestration_node::runner_bridge::{
    ImageProbeOutcome, describe_image_problem,
};
use orchestration_node::runner_settings::{
    ContainerEngineChoice, SandboxSettings,
};
use proptest::prelude::*;

const BUILD_HINT: &str = "run scripts/build-runner-image.sh";

fn any_engine() -> impl Strategy<Value = ContainerEngineChoice> {
    prop_oneof![
        Just(ContainerEngineChoice::Docker),
        Just(ContainerEngineChoice::Podman),
    ]
}

fn any_outcome() -> impl Strategy<Value = ImageProbeOutcome> {
    prop_oneof![
        Just(ImageProbeOutcome::Present),
        Just(ImageProbeOutcome::Missing),
        Just(ImageProbeOutcome::EngineStopped),
        "[a-z ]{1,20}".prop_map(ImageProbeOutcome::EngineFailed),
    ]
}

fn engine_program(engine: ContainerEngineChoice) -> &'static str {
    match engine {
        ContainerEngineChoice::Docker => "docker",
        ContainerEngineChoice::Podman => "podman",
    }
}

fn engine_name(engine: ContainerEngineChoice) -> &'static str {
    match engine {
        ContainerEngineChoice::Docker => "Docker",
        ContainerEngineChoice::Podman => "Podman",
    }
}

fn container(engine: ContainerEngineChoice, image: &str) -> SandboxSettings {
    SandboxSettings::Container {
        engine,
        image: image.to_owned(),
        allowed_hosts: Vec::new(),
    }
}

proptest! {
    #[test]
    fn test_describe_image_problem_property_local_process_needs_no_image(
        outcome in any_outcome(),
    ) {
        let probed = RefCell::new(false);

        let problem = describe_image_problem(
            &SandboxSettings::LocalProcess,
            |_engine: &str, _image: &str| {
                probed.replace(true);
                outcome.clone()
            },
        );

        prop_assert_eq!(problem, None);
        prop_assert!(!probed.into_inner());
    }

    #[test]
    fn test_describe_image_problem_property_names_a_missing_image(
        engine in any_engine(),
        image in "[a-z][a-z0-9./-]{0,30}:[a-z0-9.]{1,10}",
    ) {
        let asked = RefCell::new(None);

        let problem = describe_image_problem(
            &container(engine, &image),
            |engine_program: &str, probed_image: &str| {
                asked.replace(Some((
                    engine_program.to_owned(),
                    probed_image.to_owned(),
                )));
                ImageProbeOutcome::Missing
            },
        );

        let expected =
            format!("The runner image {image} is missing — {BUILD_HINT}");
        prop_assert_eq!(problem, Some(expected));
        let expected_probe =
            Some((engine_program(engine).to_owned(), image.clone()));
        prop_assert_eq!(asked.into_inner(), expected_probe);
    }

    #[test]
    fn test_describe_image_problem_property_present_images_are_fine(
        engine in any_engine(),
        image in "[a-z]{1,12}:[a-z0-9]{1,6}",
    ) {
        let problem = describe_image_problem(
            &container(engine, &image),
            |_engine: &str, _image: &str| ImageProbeOutcome::Present,
        );

        prop_assert_eq!(problem, None);
    }

    #[test]
    fn test_describe_image_problem_property_a_stopped_engine_says_start_it(
        engine in any_engine(),
        image in "[a-z]{1,12}:[a-z0-9]{1,6}",
    ) {
        let problem = describe_image_problem(
            &container(engine, &image),
            |_engine: &str, _image: &str| ImageProbeOutcome::EngineStopped,
        );

        let name = engine_name(engine);
        let expected = format!(
            "{name} is not running — start {name} and wait until it is ready"
        );
        prop_assert_eq!(problem, Some(expected));
    }

    #[test]
    fn test_describe_image_problem_property_a_broken_engine_says_install_it(
        engine in any_engine(),
        reason in "[a-z ]{1,30}",
    ) {
        let problem = describe_image_problem(
            &container(engine, "agents-orchestration-runner:latest"),
            |_engine: &str, _image: &str| {
                ImageProbeOutcome::EngineFailed(reason.clone())
            },
        );

        let name = engine_name(engine);
        let expected =
            format!("{name} could not be run ({reason}) — install {name}");
        prop_assert_eq!(problem, Some(expected));
    }
}
