use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use orchestration_core::device::SandboxKind;
use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::sandbox::{
    ContainerEngine, ContainerSettings, SandboxError, wrap_in_sandbox,
};
use orchestration_hub::workspace_mounts::{
    CONTAINER_WORKSPACE_DIRECTORY, PlaceholderMount, WorkspaceMounts,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::sandbox_support::any_folder;

const MOUNT_OPTION: &str = "--mount";
const READ_ONLY_ENDING: &str = ",readonly";
const PLACEHOLDER_FILE: &str =
    "/runner/protected-file-placeholders/empty-file";
const LARGEST_COVER_COUNT: usize = 5;
const RECORD_BREAKING_CHARACTERS: [char; 2] = ['\n', '\r'];
const PROTECTED_NAME: &str = "protected.key";

type CoverPlace = (String, PathBuf);

fn any_relative_cover() -> impl Strategy<Value = String> {
    concat!(
        "[a-zA-Z0-9é_ -][a-zA-Z0-9é_. -]{0,9}",
        "(/[a-zA-Z0-9é_-][a-zA-Z0-9é_. -]{0,9}){0,3}",
    )
}

fn any_cover_place() -> impl Strategy<Value = (PathBuf, Vec<CoverPlace>)> {
    (
        any_folder(),
        vec(any_relative_cover(), 1..LARGEST_COVER_COUNT),
    )
        .prop_map(|(task_folder, relative_covers)| {
            let mut places = Vec::new();
            for relative_cover in relative_covers {
                let covered = task_folder.join(&relative_cover);
                places.push((relative_cover, covered));
            }
            (task_folder, places)
        })
}

fn any_breaking_name() -> impl Strategy<Value = String> {
    (
        "[a-z]{0,4}",
        prop_oneof![
            Just(","),
            Just("\""),
            Just("\n"),
            Just("\r"),
            Just("\n,readonly=false"),
        ],
        "[a-z]{0,4}",
    )
        .prop_map(|(before, breaking, after)| {
            format!("{before}{breaking}{after}")
        })
}

fn covering(task_folder: &Path, covered_paths: &[PathBuf]) -> WorkspaceMounts {
    let mut placeholder_mounts = Vec::new();
    for covered_path in covered_paths {
        placeholder_mounts.push(PlaceholderMount {
            covered_path: covered_path.clone(),
            placeholder: PathBuf::from(PLACEHOLDER_FILE),
        });
    }
    WorkspaceMounts {
        task_folder: task_folder.to_path_buf(),
        git_directories: Vec::new(),
        placeholder_mounts,
    }
}

fn wrap_in_container(
    mounts: &WorkspaceMounts,
) -> Result<CommandSpecification, SandboxError> {
    let settings = ContainerSettings {
        engine: ContainerEngine::Docker,
        image: "agon-runner".to_owned(),
    };
    let command = CommandSpecification {
        program: "claude".to_owned(),
        arguments: Vec::new(),
        environment: BTreeMap::new(),
        working_directory: None,
    };
    wrap_in_sandbox(SandboxKind::Container, &settings, &command, mounts, &[])
}

fn list_mount_values(wrapped: &CommandSpecification) -> Vec<String> {
    let mut mount_values = Vec::new();
    for pair in wrapped.arguments.windows(2) {
        if pair[0] == MOUNT_OPTION {
            mount_values.push(pair[1].clone());
        }
    }
    mount_values
}

fn mount_values_for(
    mounts: &WorkspaceMounts,
) -> Result<Vec<String>, TestCaseError> {
    let wrapped = wrap_in_container(mounts)
        .map_err(|problem| TestCaseError::fail(problem.to_string()))?;
    Ok(list_mount_values(&wrapped))
}

fn is_refused_cover(mounts: &WorkspaceMounts) -> bool {
    let wrapped = wrap_in_container(mounts);
    matches!(wrapped, Err(SandboxError::UnsafeCoveredPath(_)))
}

proptest! {
    #[test]
    fn test_describe_placeholder_mounts_property_one_read_only_mount_each(
        (task_folder, places) in any_cover_place(),
    ) {
        let covered: Vec<PathBuf> =
            places.iter().map(|(_, covered)| covered.clone()).collect();

        let mounts = covering(&task_folder, &covered);

        let mount_values = mount_values_for(&mounts)?;

        prop_assert_eq!(mount_values.len(), covered.len() + 1);
        prop_assert!(!mount_values[0].ends_with(READ_ONLY_ENDING));
        for mount_value in &mount_values[1..] {
            prop_assert!(mount_value.ends_with(READ_ONLY_ENDING));
        }
    }

    #[test]
    fn test_describe_placeholder_mounts_property_mounts_the_placeholders(
        (task_folder, places) in any_cover_place(),
    ) {
        let covered: Vec<PathBuf> =
            places.iter().map(|(_, covered)| covered.clone()).collect();

        let mounts = covering(&task_folder, &covered);

        let mount_values = mount_values_for(&mounts)?;

        let source = format!("source={PLACEHOLDER_FILE},");
        for mount_value in &mount_values[1..] {
            prop_assert!(mount_value.contains(&source), "{mount_value}");
        }
    }

    #[test]
    fn test_describe_placeholder_mounts_property_one_bad_cover_fails_all(
        (task_folder, places) in any_cover_place(),
        outside in any_folder(),
    ) {
        prop_assume!(!outside.starts_with(&task_folder));
        let mut covered: Vec<PathBuf> =
            places.iter().map(|(_, covered)| covered.clone()).collect();
        covered.push(outside);

        prop_assert!(is_refused_cover(&covering(&task_folder, &covered)));
    }

    #[test]
    fn test_describe_covered_target_property_maps_into_the_workspace(
        (task_folder, places) in any_cover_place(),
    ) {
        let covered: Vec<PathBuf> =
            places.iter().map(|(_, covered)| covered.clone()).collect();

        let mounts = covering(&task_folder, &covered);

        let mount_values = mount_values_for(&mounts)?;

        for ((relative_cover, _), mount_value) in
            places.iter().zip(&mount_values[1..])
        {
            let relative = Path::new(relative_cover);
            let mut target = CONTAINER_WORKSPACE_DIRECTORY.to_owned();
            for component in relative.components() {
                target.push('/');
                target.push_str(&component.as_os_str().to_string_lossy());
            }
            let expected = format!(",target={target}{READ_ONLY_ENDING}");
            prop_assert!(mount_value.ends_with(&expected), "{mount_value}");
        }
    }

    #[test]
    fn test_describe_covered_target_property_refuses_paths_outside_the_task(
        task_folder in any_folder(),
        sibling_suffix in "[a-z0-9-]{1,6}",
        relative_cover in any_relative_cover(),
    ) {
        let folder_text = task_folder.display();
        let sibling_name = format!("{folder_text}{sibling_suffix}");
        let sibling_cover = PathBuf::from(sibling_name).join(&relative_cover);
        let parent_cover = task_folder.join("..").join(&relative_cover);

        let covers = [sibling_cover, parent_cover, task_folder.clone()];
        for cover in covers {
            let mounts = covering(&task_folder, &[cover]);
            prop_assert!(is_refused_cover(&mounts));
        }
    }

    #[test]
    fn test_describe_covered_target_property_refuses_record_breaking_names(
        (task_folder, places) in any_cover_place(),
        breaking_name in any_breaking_name(),
    ) {
        let mut covered: Vec<PathBuf> =
            places.iter().map(|(_, covered)| covered.clone()).collect();
        covered.push(task_folder.join(&breaking_name).join(PROTECTED_NAME));

        let wrapped = wrap_in_container(&covering(&task_folder, &covered));

        if let Ok(wrapped) = wrapped {
            for mount_value in list_mount_values(&wrapped) {
                let breaks_record =
                    mount_value.contains(RECORD_BREAKING_CHARACTERS);
                prop_assert!(!breaks_record, "{mount_value:?}");
                prop_assert_eq!(mount_value.matches('"').count(), 0);
                let field_count = mount_value.split(',').count();
                prop_assert!(field_count <= 4, "{mount_value:?}");
            }
        }
    }
}
