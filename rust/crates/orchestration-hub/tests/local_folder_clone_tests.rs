mod worktree_support;

use orchestration_core::identifiers::DeviceId;
use orchestration_core::local_folders::{LocalFolder, render_local_address};
use orchestration_hub::clone_source::{CloneSource, CloneSourceProblem};
use orchestration_hub::worktree_plan::{
    WorktreeProblem, WorktreeRequest, plan_worktree,
};
use proptest::prelude::*;
use worktree_support::{
    any_canonical_address, any_hostile_title, any_lifetime, any_task_id,
    plan_or_fail, repository_at, request_for,
};

fn any_device_id() -> impl Strategy<Value = DeviceId> {
    "[0-9a-f]{32}".prop_map(DeviceId)
}

fn any_folder_name() -> impl Strategy<Value = String> {
    "[a-z][a-z0-9]{0,10}"
}

fn any_folder_path() -> impl Strategy<Value = String> {
    ("(/[A-Za-z0-9_-]{1,8}){0,3}", any_folder_name())
        .prop_map(|(parents, name)| format!("{parents}/{name}"))
}

fn local_address(
    device_id: &DeviceId,
    path: &str,
) -> Result<String, TestCaseError> {
    let folder = LocalFolder {
        device_id: device_id.clone(),
        path: path.to_owned(),
    };
    render_local_address(&folder)
        .map_err(|problem| TestCaseError::fail(problem.to_string()))
}

proptest! {
    #[test]
    fn test_clone_url_property_folder_of_this_device_clones_its_path(
        device_id in any_device_id(),
        path in any_folder_path(),
    ) {
        let address = local_address(&device_id, &path)?;
        let source = CloneSource::standard().on_device(device_id);

        prop_assert_eq!(source.clone_url(&address), Ok(path));
    }

    #[test]
    fn test_clone_url_property_folder_of_another_device_is_refused(
        runner_device in any_device_id(),
        folder_device in any_device_id(),
        path in any_folder_path(),
    ) {
        prop_assume!(runner_device != folder_device);
        let address = local_address(&folder_device, &path)?;
        let source = CloneSource::standard().on_device(runner_device);

        let expected =
            CloneSourceProblem::FolderOnAnotherDevice(address.clone());
        prop_assert_eq!(source.clone_url(&address), Err(expected));
    }

    #[test]
    fn test_clone_url_property_folders_need_the_runner_device(
        device_id in any_device_id(),
        path in any_folder_path(),
    ) {
        let address = local_address(&device_id, &path)?;

        let expected =
            CloneSourceProblem::FolderOnAnotherDevice(address.clone());
        let clone_url = CloneSource::standard().clone_url(&address);
        prop_assert_eq!(clone_url, Err(expected));
    }

    #[test]
    fn test_on_device_property_keeps_remote_clone_urls(
        device_id in any_device_id(),
        address in any_canonical_address(),
    ) {
        let standard = CloneSource::standard();
        let on_device = standard.clone().on_device(device_id);

        let expected = standard.clone_url(&address);
        prop_assert_eq!(on_device.clone_url(&address), expected);
    }

    #[test]
    fn test_plan_worktree_property_folder_names_its_worktree(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        device_id in any_device_id(),
        parents in "(/[A-Za-z0-9_-]{1,8}){0,3}",
        name in any_folder_name(),
    ) {
        let path = format!("{parents}/{name}");
        let address = local_address(&device_id, &path)?;
        let repositories = vec![repository_at(&address)];
        let request = WorktreeRequest {
            clone_source: CloneSource::standard().on_device(device_id),
            ..request_for(task_id, &title, lifetime, repositories)
        };

        let plan = plan_or_fail(&request)?;

        let planned = &plan.repositories[0];
        prop_assert_eq!(planned.worktree.file_name(), Some(name.as_ref()));
        prop_assert!(planned.clone_command.arguments.contains(&path));
    }

    #[test]
    fn test_plan_worktree_property_folder_of_another_device_is_refused(
        task_id in any_task_id(),
        lifetime in any_lifetime(),
        runner_device in any_device_id(),
        folder_device in any_device_id(),
        path in any_folder_path(),
    ) {
        prop_assume!(runner_device != folder_device);
        let address = local_address(&folder_device, &path)?;
        let repositories = vec![repository_at(&address)];
        let request = WorktreeRequest {
            clone_source: CloneSource::standard().on_device(runner_device),
            ..request_for(task_id, "Fix it", lifetime, repositories)
        };

        let expected = WorktreeProblem::FolderOnAnotherDevice(address);
        prop_assert_eq!(plan_worktree(&request), Err(expected));
    }
}
