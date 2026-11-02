use std::process::{Command, ExitStatus, Stdio};

use crate::runner_settings::{ContainerEngineChoice, SandboxSettings};

const DOCKER_PROGRAM: &str = "docker";
const PODMAN_PROGRAM: &str = "podman";
const DOCKER_NAME: &str = "Docker";
const PODMAN_NAME: &str = "Podman";
const INFO_SUBCOMMAND: &str = "info";
const IMAGE_SUBCOMMAND: &str = "image";
const INSPECT_SUBCOMMAND: &str = "inspect";
const BUILD_HINT: &str = "run scripts/build-runner-image.sh";

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ImageProbeOutcome {
    Present,
    Missing,
    EngineStopped,
    EngineFailed(String),
}

pub fn describe_image_problem(
    sandbox: &SandboxSettings,
    probe: impl Fn(&str, &str) -> ImageProbeOutcome,
) -> Option<String> {
    let SandboxSettings::Container { engine, image, .. } = sandbox else {
        return None;
    };
    let engine_name = name_engine(*engine);
    match probe(name_engine_program(*engine), image) {
        ImageProbeOutcome::Present => None,
        ImageProbeOutcome::Missing => Some(format!(
            "The runner image {image} is missing — {BUILD_HINT}"
        )),
        ImageProbeOutcome::EngineStopped => Some(format!(
            "{engine_name} is not running — start {engine_name} and wait \
             until it is ready"
        )),
        ImageProbeOutcome::EngineFailed(reason) => Some(format!(
            "{engine_name} could not be run ({reason}) — install \
             {engine_name}"
        )),
    }
}

#[must_use]
pub fn probe_local_image(
    engine_program: &str,
    image: &str,
) -> ImageProbeOutcome {
    let engine_check = run_quietly(engine_program, &[INFO_SUBCOMMAND]);
    match engine_check {
        Ok(status) if status.success() => {}
        Ok(_) => return ImageProbeOutcome::EngineStopped,
        Err(problem) => return ImageProbeOutcome::EngineFailed(problem),
    }

    let image_arguments = [IMAGE_SUBCOMMAND, INSPECT_SUBCOMMAND, image];
    match run_quietly(engine_program, &image_arguments) {
        Ok(status) if status.success() => ImageProbeOutcome::Present,
        Ok(_) => ImageProbeOutcome::Missing,
        Err(problem) => ImageProbeOutcome::EngineFailed(problem),
    }
}

fn run_quietly(
    engine_program: &str,
    arguments: &[&str],
) -> Result<ExitStatus, String> {
    Command::new(engine_program)
        .args(arguments)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map_err(|problem| problem.to_string())
}

fn name_engine_program(engine: ContainerEngineChoice) -> &'static str {
    match engine {
        ContainerEngineChoice::Docker => DOCKER_PROGRAM,
        ContainerEngineChoice::Podman => PODMAN_PROGRAM,
    }
}

fn name_engine(engine: ContainerEngineChoice) -> &'static str {
    match engine {
        ContainerEngineChoice::Docker => DOCKER_NAME,
        ContainerEngineChoice::Podman => PODMAN_NAME,
    }
}
