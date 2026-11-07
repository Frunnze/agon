use orchestration_core::identifiers::DeviceId;
use orchestration_core::local_folders::{LocalFolder, render_local_address};
use orchestration_hub::branch_names::TASK_BRANCH_PREFIX;
use orchestration_hub::clone_source::CloneSource;
use orchestration_hub::slugs::slugify;
use orchestration_hub::task_folder_names::read_task_id;
use orchestration_hub::worktree_plan::{WorktreeLifetime, WorktreeRequest};
use proptest::prelude::*;

use crate::held_folders::to_case_error;
use crate::worktree_support::{
    any_canonical_address, any_hostile_title, any_lifetime, any_task_id,
    plan_or_fail, repository_at, request_for,
};

const FALLBACK_TITLE: &str = "task";
const FALLBACK_REPOSITORY_NAME: &str = "repository";
const LONGEST_FOLDER_NAME_BYTES: usize = 255;
const DEVICE: &str = "0123456789abcdef0123456789abcdef";

fn folder_name_of(path: &std::path::Path) -> String {
    let name = path.file_name().unwrap_or_default();
    name.to_string_lossy().into_owned()
}

fn any_slugless_title() -> impl Strategy<Value = String> {
    "[ !?.,:;/\\\\_~é中😀-]{0,12}"
}

fn any_folder_ending() -> impl Strategy<Value = String> {
    prop_oneof![
        Just(String::new()),
        Just(".git".to_owned()),
        Just("/".to_owned()),
        Just(".git/".to_owned()),
    ]
}

fn local_request(
    task_id: orchestration_core::identifiers::TaskId,
    path: &str,
) -> Result<WorktreeRequest, TestCaseError> {
    let device_id = DeviceId(DEVICE.to_owned());
    let folder = LocalFolder {
        device_id: device_id.clone(),
        path: path.to_owned(),
    };
    let address = render_local_address(&folder).map_err(to_case_error)?;
    Ok(WorktreeRequest {
        clone_source: CloneSource::standard().on_device(device_id),
        ..request_for(
            task_id,
            "Fix",
            WorktreeLifetime::PerTask,
            vec![repository_at(&address)],
        )
    })
}

proptest! {
    #[test]
    fn test_name_task_folder_property_the_folder_name_gives_back_the_task(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
    ) {
        let plan =
            plan_or_fail(&request_for(task_id, &title, lifetime, Vec::new()))?;

        let folder_name = folder_name_of(&plan.task_folder);
        prop_assert_eq!(read_task_id(&folder_name), Some(task_id));
        prop_assert_eq!(
            &plan.branch,
            &format!("{TASK_BRANCH_PREFIX}{folder_name}")
        );
        prop_assert!(folder_name.len() <= LONGEST_FOLDER_NAME_BYTES);
    }

    #[test]
    fn test_name_task_folder_property_titles_without_letters_fall_back(
        task_id in any_task_id(),
        title in any_slugless_title(),
        lifetime in any_lifetime(),
    ) {
        prop_assume!(slugify(&title).is_empty());

        let plan =
            plan_or_fail(&request_for(task_id, &title, lifetime, Vec::new()))?;

        let folder_name = folder_name_of(&plan.task_folder);
        let expected_start =
            format!("{FALLBACK_TITLE}-{}", task_id.0.simple());
        prop_assert!(
            folder_name.starts_with(&expected_start),
            "{}",
            folder_name
        );
    }

    #[test]
    fn test_name_task_folder_property_job_runs_add_only_their_number(
        task_id in any_task_id(),
        title in any_hostile_title(),
        run_number in any::<u32>(),
    ) {
        let per_task = plan_or_fail(&request_for(
            task_id,
            &title,
            WorktreeLifetime::PerTask,
            Vec::new(),
        ))?;
        let per_run = plan_or_fail(&request_for(
            task_id,
            &title,
            WorktreeLifetime::PerJobRun { run_number },
            Vec::new(),
        ))?;

        let task_folder_name = folder_name_of(&per_task.task_folder);
        let run_folder_name = folder_name_of(&per_run.task_folder);
        prop_assert_eq!(
            run_folder_name,
            format!("{task_folder_name}-run-{run_number}")
        );
    }

    #[test]
    fn test_name_repository_property_the_last_segment_names_the_folder(
        task_id in any_task_id(),
        address in any_canonical_address(),
    ) {
        let plan = plan_or_fail(&request_for(
            task_id,
            "Fix",
            WorktreeLifetime::PerTask,
            vec![repository_at(&address)],
        ))?;

        let last_segment = address.rsplit('/').next().unwrap_or_default();
        let slug =
            slugify(last_segment.strip_suffix(".git").unwrap_or(last_segment));
        let expected = if slug.is_empty() {
            FALLBACK_REPOSITORY_NAME.to_owned()
        } else {
            slug
        };
        prop_assert_eq!(
            folder_name_of(&plan.repositories[0].worktree),
            expected
        );
    }

    #[test]
    fn test_name_repository_property_folder_suffixes_are_dropped(
        task_id in any_task_id(),
        parents in "(/[A-Za-z0-9_-]{1,8}){0,3}",
        name in "[A-Za-z][A-Za-z0-9 _-]{0,10}[A-Za-z0-9]",
        ending in any_folder_ending(),
    ) {
        let path = format!("{parents}/{name}{ending}");
        let request = local_request(task_id, &path)?;

        let plan = plan_or_fail(&request)?;

        prop_assert_eq!(
            folder_name_of(&plan.repositories[0].worktree),
            slugify(&name)
        );
    }

    #[test]
    fn test_name_repository_property_names_are_plain_folder_names(
        task_id in any_task_id(),
        parents in "(/[A-Za-z0-9_-]{1,8}){0,2}",
        name in "[ A-Za-z0-9._é中-]{1,12}",
    ) {
        let path = format!("{parents}/{name}");
        let Ok(request) = local_request(task_id, &path) else {
            return Ok(());
        };

        let plan = plan_or_fail(&request)?;

        let folder_name = folder_name_of(&plan.repositories[0].worktree);
        prop_assert!(!folder_name.is_empty());
        prop_assert!(
            folder_name.bytes().all(|byte| {
                byte.is_ascii_lowercase()
                    || byte.is_ascii_digit()
                    || byte == b'-'
            }),
            "{}",
            folder_name
        );
        prop_assert!(
            !folder_name.starts_with('-') && !folder_name.ends_with('-')
        );
    }
}
