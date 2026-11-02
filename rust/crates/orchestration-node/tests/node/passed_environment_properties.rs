use std::collections::BTreeMap;
use std::path::Path;

use orchestration_node::runner_bridge::build_runner_configuration;
use orchestration_node::runner_settings::{
    ContainerEngineChoice, RunnerSettings, SandboxSettings,
};
use proptest::prelude::*;
use serde_json::json;

const DATA_DIRECTORY: &str = "/tmp/orchestration-runner-data";
const MISSING_NAME: &str = "ORCHESTRATION_TEST_MISSING_TOKEN";

fn container_settings(passed_environment: Vec<String>) -> RunnerSettings {
    RunnerSettings {
        labels: vec!["mac".to_owned()],
        slot_capacity: 1,
        sandbox: SandboxSettings::Container {
            engine: ContainerEngineChoice::Docker,
            image: "agents-orchestration-runner:latest".to_owned(),
            allowed_hosts: Vec::new(),
        },
        clone_url_template: None,
        passed_environment,
    }
}

fn any_variable_name() -> impl Strategy<Value = String> {
    "[A-Z][A-Z0-9_]{2,20}"
}

fn any_environment() -> impl Strategy<Value = BTreeMap<String, String>> {
    prop::collection::btree_map(any_variable_name(), "[ -~]{1,30}", 0..6)
}

proptest! {
    #[test]
    fn test_build_runner_configuration_property_passes_named_variables(
        process_environment in any_environment(),
        extra_name in any_variable_name(),
        extra_value in "[ -~]{1,30}",
    ) {
        let mut process_environment = process_environment;
        process_environment.insert(extra_name.clone(), extra_value);
        let passed_names: Vec<String> =
            process_environment.keys().cloned().collect();
        let settings = container_settings(passed_names);

        let configuration = build_runner_configuration(
            &settings,
            Path::new(DATA_DIRECTORY),
            &process_environment,
        );

        let Ok(configuration) = configuration else {
            return Err(TestCaseError::fail(format!("{configuration:?}")));
        };
        let agent_environment = configuration.sandbox.environment;
        prop_assert_eq!(agent_environment, process_environment);
    }

    #[test]
    fn test_build_runner_configuration_property_missing_variable_stops(
        process_environment in any_environment(),
    ) {
        let mut passed_names: Vec<String> =
            process_environment.keys().cloned().collect();
        passed_names.push(MISSING_NAME.to_owned());
        let settings = container_settings(passed_names);

        let configuration = build_runner_configuration(
            &settings,
            Path::new(DATA_DIRECTORY),
            &process_environment,
        );

        let Err(problem) = configuration else {
            return Err(TestCaseError::fail("a missing variable was accepted"));
        };
        prop_assert!(problem.to_string().contains(MISSING_NAME));
    }
}

#[test]
fn runner_settings_without_passed_environment_pass_nothing() {
    let settings_json = json!({
        "labels": ["mac"],
        "slot_capacity": 1,
        "sandbox": { "kind": "local_process" },
        "clone_url_template": null,
    });
    let Ok(settings) = serde_json::from_value::<RunnerSettings>(settings_json)
    else {
        panic!("settings without passed_environment are read");
    };

    let configuration = build_runner_configuration(
        &settings,
        Path::new(DATA_DIRECTORY),
        &BTreeMap::new(),
    );

    let Ok(configuration) = configuration else {
        panic!("the configuration builds: {configuration:?}");
    };
    assert!(configuration.sandbox.environment.is_empty());
}
