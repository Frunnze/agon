use std::path::PathBuf;

use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::workspace_mounts::{PlaceholderMount, WorkspaceMounts};
use proptest::collection::vec;
use proptest::prelude::*;

pub const WORKSPACE: &str = "/workspace";
pub const MOUNT_OPTION: &str = "--mount";
pub const BREAKING_CHARACTERS: [char; 4] = [',', '"', '\n', '\r'];
const SAFE_NAME_PATTERN: &str =
    r"[a-z0-9 '=:;$\\\téA中😀_-][a-z0-9 .'=:;$\\\téA中😀_-]{0,7}";
const HOSTILE_NAME_PATTERN: &str = r#"[a-z0-9 ,"'=:;$\\\t\n\réA中😀_.-]{1,8}"#;
const CURRENT_FOLDER: &str = ".";
const READ_ONLY_FIELD: &str = "readonly";
const BIND_TYPE: &str = "bind";

#[derive(Clone, Debug)]
pub struct HostileMounts {
    pub mounts: WorkspaceMounts,
    pub covered_names: Vec<Vec<String>>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DockerMount {
    pub source: String,
    pub target: String,
    pub is_read_only: bool,
}

pub fn any_safe_name() -> BoxedStrategy<String> {
    SAFE_NAME_PATTERN.boxed()
}

pub fn any_hostile_name() -> BoxedStrategy<String> {
    HOSTILE_NAME_PATTERN.boxed()
}

pub fn path_from_names(names: &[String]) -> PathBuf {
    let mut path = PathBuf::from("/");
    for name in names {
        path.push(name);
    }
    path
}

pub fn any_mounts_named_by(
    name: BoxedStrategy<String>,
) -> impl Strategy<Value = HostileMounts> {
    let task_names = vec(name.clone(), 1..4);
    let git_names = vec(vec(name.clone(), 1..3), 0..3);
    let covered_names = vec(vec(name.clone(), 1..3), 0..3);
    let placeholder_names = vec(name, 1..3);
    (task_names, git_names, covered_names, placeholder_names).prop_map(
        |(task_names, git_names, covered_names, placeholder_names)| {
            build_mounts(
                &task_names,
                &git_names,
                covered_names,
                &placeholder_names,
            )
        },
    )
}

fn build_mounts(
    task_names: &[String],
    git_names: &[Vec<String>],
    covered_names: Vec<Vec<String>>,
    placeholder_names: &[String],
) -> HostileMounts {
    let task_folder = path_from_names(task_names);
    let mut git_directories = Vec::new();
    for clone_names in git_names {
        git_directories.push(path_from_names(clone_names).join(".git"));
    }
    let placeholder = path_from_names(placeholder_names);
    let mut placeholder_mounts = Vec::new();
    for names in &covered_names {
        let mut covered_path = task_folder.clone();
        for name in names {
            covered_path.push(name);
        }
        placeholder_mounts.push(PlaceholderMount {
            covered_path,
            placeholder: placeholder.clone(),
        });
    }
    let mounts = WorkspaceMounts {
        task_folder,
        git_directories,
        placeholder_mounts,
    };
    HostileMounts {
        mounts,
        covered_names,
    }
}

pub fn read_mount_like_docker(value: &str) -> Option<DockerMount> {
    let record = value.trim().lines().next().unwrap_or_default();
    if record.contains('"') {
        return None;
    }

    let mut mount_type = None;
    let mut source = None;
    let mut target = None;
    let mut is_read_only = false;
    for field in record.split(',') {
        match field.split_once('=') {
            None if field == READ_ONLY_FIELD => is_read_only = true,
            Some(("type", given)) => mount_type = Some(given),
            Some(("source", given)) => source = Some(given.to_owned()),
            Some(("target", given)) => target = Some(given.to_owned()),
            _ => return None,
        }
    }
    if mount_type != Some(BIND_TYPE) {
        return None;
    }
    Some(DockerMount {
        source: source?,
        target: target?,
        is_read_only,
    })
}

pub fn intended_target(covered_names: &[String]) -> String {
    let mut target = WORKSPACE.to_owned();
    for name in covered_names {
        if name != CURRENT_FOLDER {
            target.push('/');
            target.push_str(name);
        }
    }
    target
}

pub fn intended_mounts(hostile: &HostileMounts) -> Vec<DockerMount> {
    let mounts = &hostile.mounts;
    let mut intended = vec![DockerMount {
        source: mounts.task_folder.display().to_string(),
        target: WORKSPACE.to_owned(),
        is_read_only: false,
    }];
    for git_directory in &mounts.git_directories {
        let shown = git_directory.display().to_string();
        intended.push(DockerMount {
            source: shown.clone(),
            target: shown,
            is_read_only: false,
        });
    }
    let covers = mounts.placeholder_mounts.iter().zip(&hostile.covered_names);
    for (placeholder_mount, names) in covers {
        intended.push(DockerMount {
            source: placeholder_mount.placeholder.display().to_string(),
            target: intended_target(names),
            is_read_only: true,
        });
    }
    intended
}

pub fn container_options<'wrapped>(
    wrapped: &'wrapped CommandSpecification,
    command: &CommandSpecification,
) -> &'wrapped [String] {
    let options_length = wrapped.arguments.len() - command.arguments.len() - 2;
    &wrapped.arguments[..options_length]
}

pub fn mount_values(options: &[String]) -> Vec<String> {
    let mut values = Vec::new();
    for pair in options.windows(2) {
        if pair[0] == MOUNT_OPTION {
            values.push(pair[1].clone());
        }
    }
    values
}

pub fn has_breaking_character(mounts: &WorkspaceMounts) -> bool {
    let mut paths = vec![mounts.task_folder.clone()];
    paths.extend(mounts.git_directories.iter().cloned());
    for placeholder_mount in &mounts.placeholder_mounts {
        paths.push(placeholder_mount.covered_path.clone());
        paths.push(placeholder_mount.placeholder.clone());
    }
    paths
        .iter()
        .any(|path| path.display().to_string().contains(BREAKING_CHARACTERS))
}
