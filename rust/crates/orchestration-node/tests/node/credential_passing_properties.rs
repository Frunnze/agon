use std::collections::BTreeMap;

use orchestration_core::device::SandboxKind;
use orchestration_hub::sandbox::{ContainerEngine, ContainerSettings};
use orchestration_node::agent_credentials::{
    AgentCredential, AgentCredentialKind,
};
use orchestration_node::runner_bridge::{
    choose_container_credential, pass_agent_credential,
};
use orchestration_node::runner_settings::{
    ContainerEngineChoice, SandboxSettings,
};
use orchestration_runner::agent_sandbox::AgentSandbox;
use proptest::prelude::*;

fn any_credential() -> impl Strategy<Value = AgentCredential> {
    (
        prop_oneof![
            Just(AgentCredentialKind::LongLivedToken),
            Just(AgentCredentialKind::ApiKey),
        ],
        "sk-ant-[A-Za-z0-9_-]{8,60}",
    )
        .prop_filter_map("the secret is valid", |(kind, secret)| {
            AgentCredential::new(kind, &secret).ok()
        })
}

fn any_container_settings() -> impl Strategy<Value = SandboxSettings> {
    (
        prop_oneof![
            Just(ContainerEngineChoice::Docker),
            Just(ContainerEngineChoice::Podman),
        ],
        "[a-z][a-z0-9-]{0,12}:[a-z0-9]{1,6}",
    )
        .prop_map(|(engine, image)| SandboxSettings::Container {
            engine,
            image,
            allowed_hosts: Vec::new(),
        })
}

fn any_environment() -> impl Strategy<Value = BTreeMap<String, String>> {
    proptest::collection::btree_map(
        "[A-Z][A-Z0-9_]{2,12}",
        "[ -~]{1,20}",
        0..5,
    )
}

fn any_agent_sandbox() -> impl Strategy<Value = AgentSandbox> {
    (
        prop_oneof![
            Just(SandboxKind::Container),
            Just(SandboxKind::LocalProcess),
        ],
        any_environment(),
    )
        .prop_map(|(kind, environment)| AgentSandbox {
            kind,
            container: ContainerSettings {
                engine: ContainerEngine::Docker,
                image: "agents-orchestration-runner:latest".to_owned(),
            },
            allowed_hosts: Vec::new(),
            environment,
        })
}

proptest! {
    #[test]
    fn test_choose_container_credential_property_containers_keep_it(
        sandbox in any_container_settings(),
        credential in proptest::option::of(any_credential()),
    ) {
        let chosen = choose_container_credential(&sandbox, credential.clone());

        prop_assert_eq!(chosen, credential);
    }

    #[test]
    fn test_choose_container_credential_property_local_runs_never_get_it(
        credential in proptest::option::of(any_credential()),
    ) {
        let chosen = choose_container_credential(
            &SandboxSettings::LocalProcess,
            credential,
        );

        prop_assert_eq!(chosen, None);
    }

    #[test]
    fn test_pass_agent_credential_property_adds_only_the_named_variable(
        sandbox in any_agent_sandbox(),
        credential in any_credential(),
    ) {
        let passed = pass_agent_credential(&sandbox, Some(&credential));

        let mut expected = sandbox.environment.clone();
        expected.insert(
            credential.environment_variable().to_owned(),
            credential.secret().to_owned(),
        );
        prop_assert_eq!(&passed.environment, &expected);
        prop_assert_eq!(passed.kind, sandbox.kind);
        prop_assert_eq!(passed.container, sandbox.container);
    }

    #[test]
    fn test_pass_agent_credential_property_nothing_to_pass_changes_nothing(
        sandbox in any_agent_sandbox(),
    ) {
        prop_assert_eq!(pass_agent_credential(&sandbox, None), sandbox);
    }
}
