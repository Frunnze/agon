use std::collections::BTreeMap;
use std::ffi::OsStr;
use std::os::unix::ffi::OsStrExt;
use std::path::PathBuf;

use orchestration_core::device::SandboxKind;
use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::sandbox::{
    ContainerEngine, ContainerSettings, SandboxError, wrap_in_sandbox,
};
use orchestration_hub::workspace_mounts::WorkspaceMounts;
use proptest::prelude::*;

const PARENT_PART: &str = "..";
const CURRENT_PART: &str = ".";
const SEPARATOR: char = '/';

fn any_path_text() -> impl Strategy<Value = String> {
    let part = prop_oneof![
        Just("..".to_owned()),
        Just(".".to_owned()),
        Just(String::new()),
        Just("...".to_owned()),
        Just("\u{2024}\u{2024}".to_owned()),
        Just("\u{FF0F}..\u{FF0F}".to_owned()),
        Just(".. ".to_owned()),
        "[a-zé中 _-]{1,6}",
    ];
    (any::<bool>(), proptest::collection::vec(part, 0..6)).prop_map(
        |(is_absolute, parts)| {
            let joined = parts.join("/");
            if is_absolute {
                format!("/{joined}")
            } else {
                joined
            }
        },
    )
}

fn is_plain_by_model(path: &str) -> bool {
    if !path.starts_with(SEPARATOR) {
        return false;
    }
    let mut named_parts = 0;
    for part in path.split(SEPARATOR) {
        if part == PARENT_PART {
            return false;
        }
        if !part.is_empty() && part != CURRENT_PART {
            named_parts += 1;
        }
    }
    named_parts > 0
}

fn local_wrapping(
    task_folder: PathBuf,
) -> Result<CommandSpecification, SandboxError> {
    let container = ContainerSettings {
        engine: ContainerEngine::Docker,
        image: "agent".to_owned(),
    };
    let command = CommandSpecification {
        program: "true".to_owned(),
        arguments: Vec::new(),
        environment: BTreeMap::new(),
        working_directory: None,
    };
    let mounts = WorkspaceMounts {
        task_folder,
        git_directories: Vec::new(),
        placeholder_mounts: Vec::new(),
    };
    wrap_in_sandbox(
        SandboxKind::LocalProcess,
        &container,
        &command,
        &mounts,
        &[],
    )
}

fn is_accepted(path: PathBuf) -> bool {
    let wrapped = local_wrapping(path.clone());
    match wrapped {
        Ok(command) => command.working_directory == Some(path),
        Err(_) => false,
    }
}

proptest! {
    #[test]
    fn test_is_plain_absolute_path_property_agrees_with_a_model(
        path in any_path_text(),
    ) {
        let accepted = is_accepted(PathBuf::from(&path));

        prop_assert_eq!(accepted, is_plain_by_model(&path), "{:?}", path);
    }

    #[test]
    fn test_is_plain_absolute_path_property_parent_parts_are_refused(
        before in proptest::collection::vec("[a-z]{1,6}", 0..4),
        after in proptest::collection::vec("[a-z]{1,6}", 0..4),
    ) {
        let mut parts = before.clone();
        parts.push(PARENT_PART.to_owned());
        parts.extend(after.iter().cloned());
        let path = PathBuf::from(format!("/{}", parts.join("/")));

        let wrapped = local_wrapping(path.clone());

        let refusal = SandboxError::UnsafeWorkspaceDirectory(path);
        prop_assert_eq!(wrapped, Err(refusal));
    }

    #[test]
    fn test_is_plain_absolute_path_property_relative_paths_are_refused(
        parts in proptest::collection::vec("[a-z.]{1,6}", 1..4),
    ) {
        let path = PathBuf::from(parts.join("/"));

        prop_assert!(!is_accepted(path));
    }

    #[test]
    fn test_is_plain_absolute_path_property_the_root_alone_is_refused(
        noise in proptest::collection::vec(
            prop_oneof![Just("/"), Just("./")],
            0..4,
        ),
    ) {
        let path = PathBuf::from(format!("/{}", noise.concat()));

        prop_assert!(!is_accepted(path));
    }

    #[test]
    fn test_is_plain_absolute_path_property_unreadable_names_are_refused(
        folders in proptest::collection::vec("[a-z]{1,6}", 0..3),
        byte in 0x80_u8..=0xff,
    ) {
        let mut text = format!("/{}", folders.join("/")).into_bytes();
        text.extend_from_slice(&[b'/', b'x', byte]);
        let path = PathBuf::from(OsStr::from_bytes(&text));
        prop_assume!(path.to_str().is_none());

        prop_assert!(!is_accepted(path));
    }
}
