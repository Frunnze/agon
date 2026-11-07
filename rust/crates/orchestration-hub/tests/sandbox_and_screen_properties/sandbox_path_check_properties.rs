use std::path::PathBuf;

use orchestration_core::device::SandboxKind;
use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::sandbox::{
    ContainerEngine, ContainerSettings, SandboxError, wrap_in_sandbox,
};
use orchestration_hub::workspace_mounts::{PlaceholderMount, WorkspaceMounts};
use proptest::prelude::*;
use proptest::sample::select;

use crate::hostile_mounts::{
    BREAKING_CHARACTERS, HostileMounts, any_mounts_named_by, any_safe_name,
    has_breaking_character, path_from_names,
};
use crate::sandbox_mount_properties::{agent_command, agent_settings};
use crate::sandbox_support::{any_inner_command, wrap_in_container};

const PLAIN_HOSTILE_NAME_PATTERN: &str =
    r#"[a-z0-9 ,"'=:;$\\\t\n\réA中😀_-]{1,8}"#;
const WRONG_GIT_NAMES: [&str; 6] =
    [".gitx", "git", ".GIT", ".git ", " .git", "x.git"];

#[derive(Clone, Copy, Debug)]
enum InjectedPath {
    TaskFolder,
    GitDirectory,
    CoveredPath,
    Placeholder,
}

fn any_injected_path() -> impl Strategy<Value = InjectedPath> {
    select(vec![
        InjectedPath::TaskFolder,
        InjectedPath::GitDirectory,
        InjectedPath::CoveredPath,
        InjectedPath::Placeholder,
    ])
}

fn broken_name(prefix: &str, breaking: char, suffix: &str) -> String {
    format!("{prefix}{breaking}{suffix}")
}

fn inject(
    hostile: &HostileMounts,
    injected_path: InjectedPath,
    name: &str,
) -> (WorkspaceMounts, SandboxError) {
    let mut mounts = hostile.mounts.clone();
    let task_folder = mounts.task_folder.clone();
    match injected_path {
        InjectedPath::TaskFolder => {
            let broken = task_folder.join(name);
            mounts.task_folder.clone_from(&broken);
            (mounts, SandboxError::UnsafeWorkspaceDirectory(broken))
        }
        InjectedPath::GitDirectory => {
            let broken = path_from_names(&[name.to_owned()]).join(".git");
            mounts.git_directories.insert(0, broken.clone());
            (mounts, SandboxError::UnsafeGitDirectory(broken))
        }
        InjectedPath::CoveredPath | InjectedPath::Placeholder => {
            let mut covered_path = task_folder.join("covered");
            let mut placeholder = PathBuf::from("/placeholders/empty");
            if matches!(injected_path, InjectedPath::CoveredPath) {
                covered_path = task_folder.join(name);
            } else {
                placeholder = placeholder.join(name);
            }
            mounts.placeholder_mounts.insert(
                0,
                PlaceholderMount {
                    covered_path: covered_path.clone(),
                    placeholder,
                },
            );
            (mounts, SandboxError::UnsafeCoveredPath(covered_path))
        }
    }
}

fn mounts_with_git(git_directory: PathBuf) -> WorkspaceMounts {
    WorkspaceMounts {
        task_folder: PathBuf::from("/task"),
        git_directories: vec![git_directory],
        placeholder_mounts: Vec::new(),
    }
}

fn wrap_for_docker(mounts: &WorkspaceMounts) -> Result<(), SandboxError> {
    let command = agent_command(&[]);
    let settings = agent_settings(ContainerEngine::Docker);
    wrap_in_container(&settings, &command, mounts, &[]).map(|_wrapped| ())
}

proptest! {
    #[test]
    fn test_breaks_mount_syntax_property_each_breaking_character_is_refused(
        hostile in any_mounts_named_by(any_safe_name()),
        injected_path in any_injected_path(),
        breaking in select(BREAKING_CHARACTERS.to_vec()),
        prefix in "[a-z]{0,3}",
        suffix in "[a-z]{0,3}",
    ) {
        let name = broken_name(&prefix, breaking, &suffix);
        let (mounts, expected) = inject(&hostile, injected_path, &name);

        prop_assert_eq!(wrap_for_docker(&mounts), Err(expected));
    }

    #[test]
    fn test_breaks_mount_syntax_property_newlines_never_drop_read_only(
        hostile in any_mounts_named_by(any_safe_name()),
        line_end in select(vec!["\n", "\r", "\r\n"]),
        prefix in "[a-z]{1,3}",
    ) {
        let name = format!("{prefix}{line_end}");
        let (mounts, expected) =
            inject(&hostile, InjectedPath::CoveredPath, &name);

        prop_assert_eq!(wrap_for_docker(&mounts), Err(expected));
    }

    #[test]
    fn test_breaks_mount_syntax_property_refuses_exactly_the_breaking_paths(
        hostile in any_mounts_named_by(PLAIN_HOSTILE_NAME_PATTERN.boxed()),
    ) {
        let is_refused = wrap_for_docker(&hostile.mounts).is_err();

        prop_assert_eq!(is_refused, has_breaking_character(&hostile.mounts));
    }

    #[test]
    fn test_ensure_mountable_task_folder_property_runs_before_other_checks(
        hostile in any_mounts_named_by(any_safe_name()),
        breaking in select(BREAKING_CHARACTERS.to_vec()),
        image in prop_oneof![Just(String::new()), Just("-x".to_owned())],
    ) {
        let name = broken_name("task", breaking, "");
        let (mounts, expected) =
            inject(&hostile, InjectedPath::TaskFolder, &name);
        let settings = ContainerSettings {
            engine: ContainerEngine::Podman,
            image,
        };
        let hosts = vec![String::new()];

        let wrapped =
            wrap_in_container(&settings, &agent_command(&[]), &mounts, &hosts);

        prop_assert_eq!(wrapped, Err(expected));
    }

    #[test]
    fn test_ensure_mountable_task_folder_property_local_runs_accept_any_name(
        hostile in any_mounts_named_by(any_safe_name()),
        breaking in select(BREAKING_CHARACTERS.to_vec()),
        command in any_inner_command(),
    ) {
        let name = broken_name("task", breaking, "");
        let (mounts, _expected) =
            inject(&hostile, InjectedPath::TaskFolder, &name);
        let settings = agent_settings(ContainerEngine::Docker);

        let wrapped = wrap_in_sandbox(
            SandboxKind::LocalProcess,
            &settings,
            &command,
            &mounts,
            &[],
        );

        let expected = CommandSpecification {
            working_directory: Some(mounts.task_folder.clone()),
            ..command
        };
        prop_assert_eq!(wrapped, Ok(expected));
    }

    #[test]
    fn test_ensure_mountable_task_folder_property_names_the_exact_folder(
        task_names in proptest::collection::vec(
            PLAIN_HOSTILE_NAME_PATTERN,
            1..4,
        ),
    ) {
        let task_folder = path_from_names(&task_names);
        let mounts = WorkspaceMounts {
            task_folder: task_folder.clone(),
            git_directories: Vec::new(),
            placeholder_mounts: Vec::new(),
        };
        prop_assume!(has_breaking_character(&mounts));

        let expected = SandboxError::UnsafeWorkspaceDirectory(task_folder);
        prop_assert_eq!(wrap_for_docker(&mounts), Err(expected));
    }

    #[test]
    fn test_ensure_mountable_git_directories_property_first_bad_is_named(
        hostile in any_mounts_named_by(any_safe_name()),
        first_wrong in select(WRONG_GIT_NAMES.to_vec()),
        second_wrong in select(WRONG_GIT_NAMES.to_vec()),
    ) {
        let mut mounts = hostile.mounts.clone();
        let first = PathBuf::from("/first").join(first_wrong);
        let second = PathBuf::from("/second").join(second_wrong);
        mounts.git_directories.push(first.clone());
        mounts.git_directories.push(second);

        let expected = SandboxError::UnsafeGitDirectory(first);
        prop_assert_eq!(wrap_for_docker(&mounts), Err(expected));
    }

    #[test]
    fn test_ensure_mountable_git_directories_property_only_dot_git_is_used(
        clone_names in proptest::collection::vec(any_safe_name(), 1..3),
        wrong_name in select(WRONG_GIT_NAMES.to_vec()),
    ) {
        let clone = path_from_names(&clone_names);
        let wrong = clone.join(wrong_name);

        let right = wrap_for_docker(&mounts_with_git(clone.join(".git")));
        let refused = wrap_for_docker(&mounts_with_git(wrong.clone()));

        prop_assert_eq!(right, Ok(()));
        prop_assert_eq!(refused, Err(SandboxError::UnsafeGitDirectory(wrong)));
    }

    #[test]
    fn test_ensure_mountable_git_directories_property_checked_before_image(
        hostile in any_mounts_named_by(any_safe_name()),
        breaking in select(BREAKING_CHARACTERS.to_vec()),
    ) {
        let name = broken_name("clone", breaking, "");
        let (mounts, expected) =
            inject(&hostile, InjectedPath::GitDirectory, &name);
        let settings = ContainerSettings {
            engine: ContainerEngine::Docker,
            image: " ".to_owned(),
        };

        let wrapped =
            wrap_in_container(&settings, &agent_command(&[]), &mounts, &[]);

        prop_assert_eq!(wrapped, Err(expected));
    }
}
