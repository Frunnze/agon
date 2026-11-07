use std::path::PathBuf;

use orchestration_core::device::SandboxKind;
use orchestration_hub::utf8_chunks::drain_complete_text;
use orchestration_hub::workspace_mounts::{
    CONTAINER_WORKSPACE_DIRECTORY, PlaceholderMount, WorkspaceMounts,
    locate_task_folder_seen_by_agent,
};
use proptest::collection::vec;
use proptest::prelude::*;

const LONGEST_UTF8_SEQUENCE: usize = 4;

fn any_folder() -> impl Strategy<Value = PathBuf> {
    "(/[a-zA-Z0-9 ._é-]{1,10}){1,5}".prop_map(PathBuf::from)
}

fn any_mounts() -> impl Strategy<Value = WorkspaceMounts> {
    let placeholder = (any_folder(), any_folder()).prop_map(
        |(covered_path, placeholder)| PlaceholderMount {
            covered_path,
            placeholder,
        },
    );
    (
        any_folder(),
        vec(any_folder(), 0..3),
        vec(placeholder, 0..3),
    )
        .prop_map(|(task_folder, git_directories, placeholder_mounts)| {
            WorkspaceMounts {
                task_folder,
                git_directories,
                placeholder_mounts,
            }
        })
}

fn any_isolated_sandbox() -> impl Strategy<Value = SandboxKind> {
    prop_oneof![
        Just(SandboxKind::Container),
        Just(SandboxKind::MicroVirtualMachine),
    ]
}

fn could_still_become_a_character(pending: &[u8]) -> bool {
    let Some(first) = pending.first() else {
        return true;
    };
    let expected_length = match first {
        0xC2..=0xDF => 2,
        0xE0..=0xEF => 3,
        0xF0..=0xF4 => 4,
        _ => return false,
    };
    let are_continuations =
        pending[1..].iter().all(|byte| (0x80..0xC0).contains(byte));
    pending.len() < expected_length && are_continuations
}

proptest! {
    #[test]
    fn test_drain_complete_text_property_waits_only_for_a_cut_character(
        bytes in vec(any::<u8>(), 0..60),
    ) {
        let mut pending = bytes.clone();

        let drained = drain_complete_text(&mut pending);

        let drained_length = bytes.len() - pending.len();
        let expected = String::from_utf8_lossy(&bytes[..drained_length]);
        prop_assert_eq!(drained, expected.into_owned());
        prop_assert!(pending.len() < LONGEST_UTF8_SEQUENCE);
        prop_assert!(
            could_still_become_a_character(&pending),
            "{:?}",
            pending
        );
    }

    #[test]
    fn test_drain_complete_text_property_draining_again_takes_nothing(
        bytes in vec(any::<u8>(), 0..60),
    ) {
        let mut pending = bytes;
        let _first = drain_complete_text(&mut pending);
        let waiting = pending.clone();

        let second = drain_complete_text(&mut pending);

        prop_assert_eq!(second, String::new());
        prop_assert_eq!(pending, waiting);
    }

    #[test]
    fn test_locate_task_folder_seen_by_agent_property_local_sees_real_folder(
        mounts in any_mounts(),
    ) {
        let seen = locate_task_folder_seen_by_agent(
            SandboxKind::LocalProcess,
            &mounts,
        );

        prop_assert_eq!(seen, mounts.task_folder);
    }

    #[test]
    fn test_locate_task_folder_seen_by_agent_property_isolated_see_workspace(
        sandbox in any_isolated_sandbox(),
        mounts in any_mounts(),
    ) {
        let seen = locate_task_folder_seen_by_agent(sandbox, &mounts);

        prop_assert!(seen.is_absolute());
        prop_assert_eq!(seen, PathBuf::from(CONTAINER_WORKSPACE_DIRECTORY));
    }

    #[test]
    fn test_locate_task_folder_seen_by_agent_property_ignores_other_mounts(
        sandbox in prop_oneof![
            Just(SandboxKind::LocalProcess),
            any_isolated_sandbox(),
        ],
        mounts in any_mounts(),
        other_mounts in any_mounts(),
    ) {
        let changed = WorkspaceMounts {
            task_folder: mounts.task_folder.clone(),
            ..other_mounts
        };

        let seen = locate_task_folder_seen_by_agent(sandbox, &mounts);
        let seen_with_changed =
            locate_task_folder_seen_by_agent(sandbox, &changed);

        prop_assert_eq!(seen, seen_with_changed);
    }
}
