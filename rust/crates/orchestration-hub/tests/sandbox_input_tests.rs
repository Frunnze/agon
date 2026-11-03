mod sandbox_support;

use orchestration_core::device::SandboxKind;
use orchestration_hub::sandbox::{
    wrap_in_sandbox, wrap_in_sandbox_keeping_input_open,
};
use proptest::prelude::*;
use sandbox_support::{
    any_hosts, any_inner_command, any_mounts, any_settings, wrap_in_container,
};

const KEEP_INPUT_OPEN_OPTION: &str = "--interactive";

proptest! {
    #[test]
    fn test_wrap_in_sandbox_keeping_input_open_property_container_listens(
        (settings, _program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
        hosts in any_hosts(),
    ) {
        let closed = wrap_in_container(&settings, &command, &mounts, &hosts)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
        let image_position =
            closed.arguments.len() - command.arguments.len() - 2;
        let mut expected = closed.clone();
        expected
            .arguments
            .insert(image_position, KEEP_INPUT_OPEN_OPTION.to_string());

        let kept_open = wrap_in_sandbox_keeping_input_open(
            SandboxKind::Container,
            &settings,
            &command,
            &mounts,
            &hosts,
        );

        prop_assert_eq!(kept_open, Ok(expected));
    }

    #[test]
    fn test_wrap_in_sandbox_keeping_input_open_property_local_is_unchanged(
        (settings, _program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
        hosts in any_hosts(),
    ) {
        let kind = SandboxKind::LocalProcess;
        let closed =
            wrap_in_sandbox(kind, &settings, &command, &mounts, &hosts);

        let kept_open = wrap_in_sandbox_keeping_input_open(
            kind,
            &settings,
            &command,
            &mounts,
            &hosts,
        );

        prop_assert_eq!(kept_open, closed);
    }

    #[test]
    fn test_wrap_in_sandbox_property_closed_input_never_listens(
        (settings, _program) in any_settings(),
        command in any_inner_command(),
        mounts in any_mounts(),
        hosts in any_hosts(),
    ) {
        let option = KEEP_INPUT_OPEN_OPTION.to_string();
        prop_assume!(!command.arguments.contains(&option));

        let closed = wrap_in_container(&settings, &command, &mounts, &hosts)
            .map_err(|problem| TestCaseError::fail(problem.to_string()))?;

        let listens = closed
            .arguments
            .iter()
            .any(|argument| argument == KEEP_INPUT_OPEN_OPTION);
        prop_assert!(!listens);
    }
}
