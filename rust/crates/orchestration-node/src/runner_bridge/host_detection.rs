use std::collections::BTreeSet;
use std::env;
use std::path::Path;
use std::thread;

use crate::runner_settings::{
    ContainerEngineChoice, RunnerSettings, SandboxSettings,
};

const SEARCH_PATH_VARIABLE: &str = "PATH";
const XCODE_PROGRAM: &str = "xcodebuild";
const DOCKER_PROGRAM: &str = "docker";
const PODMAN_PROGRAM: &str = "podman";
const PROBED_PROGRAMS: [&str; 3] =
    [XCODE_PROGRAM, DOCKER_PROGRAM, PODMAN_PROGRAM];
const XCODE_LABEL: &str = "xcode";
const SYSTEM_LABELS: [(&str, &str); 1] = [("macos", "mac")];
const PROCESSOR_LABELS: [(&str, &str); 2] =
    [("aarch64", "arm64"), ("x86_64", "x64")];
const PROCESSORS_PER_SLOT: usize = 2;
const FEWEST_SLOTS: u32 = 1;
const DEFAULT_CONTAINER_IMAGE: &str = "agents-orchestration-runner:latest";
#[cfg(unix)]
const ANY_EXECUTE_BITS: u32 = 0o111;
const DEFAULT_ALLOWED_HOSTS: [&str; 4] = [
    "api.anthropic.com",
    "api.openai.com",
    "generativelanguage.googleapis.com",
    "github.com",
];

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct HostFacts {
    pub operating_system: String,
    pub architecture: String,
    pub processor_count: usize,
    pub programs_found: BTreeSet<String>,
}

#[must_use]
pub fn read_host_facts() -> HostFacts {
    let processor_count =
        thread::available_parallelism().map_or(1, std::num::NonZero::get);
    let mut programs_found = BTreeSet::new();
    for program in PROBED_PROGRAMS {
        if is_program_on_path(program) {
            programs_found.insert(program.to_owned());
        }
    }
    HostFacts {
        operating_system: env::consts::OS.to_owned(),
        architecture: env::consts::ARCH.to_owned(),
        processor_count,
        programs_found,
    }
}

#[must_use]
pub fn detect_runner_settings(facts: &HostFacts) -> RunnerSettings {
    let half_of_processors = facts.processor_count / PROCESSORS_PER_SLOT;
    let slot_capacity = u32::try_from(half_of_processors)
        .unwrap_or(u32::MAX)
        .max(FEWEST_SLOTS);
    RunnerSettings {
        labels: describe_labels(facts),
        slot_capacity,
        sandbox: choose_sandbox(facts),
        clone_url_template: None,
        passed_environment: Vec::new(),
    }
}

fn describe_labels(facts: &HostFacts) -> Vec<String> {
    let mut candidates = vec![
        translate(&facts.operating_system, &SYSTEM_LABELS),
        translate(&facts.architecture, &PROCESSOR_LABELS),
    ];
    if facts.programs_found.contains(XCODE_PROGRAM) {
        candidates.push(XCODE_LABEL.to_owned());
    }
    let mut labels = Vec::new();
    for candidate in candidates {
        if !labels.contains(&candidate) {
            labels.push(candidate);
        }
    }
    labels
}

fn translate(name: &str, translations: &[(&str, &str)]) -> String {
    let translated = translations
        .iter()
        .find(|(original, _label)| *original == name)
        .map_or(name, |(_original, label)| label);
    translated.to_owned()
}

#[must_use]
pub fn detect_container_sandbox(facts: &HostFacts) -> SandboxSettings {
    let has_docker = facts.programs_found.contains(DOCKER_PROGRAM);
    let has_podman = facts.programs_found.contains(PODMAN_PROGRAM);
    let engine = if has_podman && !has_docker {
        ContainerEngineChoice::Podman
    } else {
        ContainerEngineChoice::Docker
    };
    SandboxSettings::Container {
        engine,
        image: DEFAULT_CONTAINER_IMAGE.to_owned(),
        allowed_hosts: DEFAULT_ALLOWED_HOSTS.map(str::to_owned).to_vec(),
    }
}

fn choose_sandbox(facts: &HostFacts) -> SandboxSettings {
    let has_engine = facts.programs_found.contains(DOCKER_PROGRAM)
        || facts.programs_found.contains(PODMAN_PROGRAM);
    if has_engine {
        return detect_container_sandbox(facts);
    }
    SandboxSettings::LocalProcess
}

fn is_program_on_path(program: &str) -> bool {
    let Some(search_path) = env::var_os(SEARCH_PATH_VARIABLE) else {
        return false;
    };
    env::split_paths(&search_path)
        .any(|folder| is_executable_file(&folder.join(program)))
}

#[cfg(unix)]
fn is_executable_file(path: &Path) -> bool {
    use std::os::unix::fs::PermissionsExt;

    path.metadata().is_ok_and(|metadata| {
        metadata.is_file()
            && metadata.permissions().mode() & ANY_EXECUTE_BITS != 0
    })
}

#[cfg(not(unix))]
fn is_executable_file(path: &Path) -> bool {
    path.is_file()
}
