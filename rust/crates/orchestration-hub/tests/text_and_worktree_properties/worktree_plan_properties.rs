use std::ffi::OsStr;
use std::os::unix::ffi::OsStrExt;
use std::path::PathBuf;
use std::process::Command;

use orchestration_core::identifiers::DeviceId;
use orchestration_core::local_folders::{LocalFolder, render_local_address};
use orchestration_hub::clone_source::{ADDRESS_PLACEHOLDER, CloneSource};
use orchestration_hub::slugs::slugify;
use orchestration_hub::worktree_plan::{
    WorktreeLifetime, WorktreeProblem, WorktreeRequest, plan_worktree,
};
use proptest::prelude::*;

use crate::held_folders::{create_held_folders, to_case_error};
use crate::worktree_support::{
    any_canonical_address, any_hostile_title, any_lifetime, any_task_id,
    plan_or_fail, repository_at, request_for,
};

const PLAIN_ROOT: &str = "/runner/plain";

fn any_unsafe_root() -> impl Strategy<Value = PathBuf> {
    prop_oneof![
        "(/[a-z]{1,6}){0,2}/\\.\\.(/[a-z]{1,6}){0,2}".prop_map(PathBuf::from),
        "[a-z]{1,6}(/[a-z]{1,6}){0,2}".prop_map(PathBuf::from),
        Just(PathBuf::from("/")),
        Just(PathBuf::from("")),
        Just(PathBuf::from(OsStr::from_bytes(b"/runner/\xff"))),
    ]
}

fn any_default_branch() -> impl Strategy<Value = String> {
    prop_oneof![
        "[a-z@.{}/~^:?*\\[\\\\ é-]{1,8}",
        "[a-z]{1,5}(/[a-z.]{1,5}){0,2}",
        Just("@".to_owned()),
        Just("HEAD".to_owned()),
        Just("a.lock".to_owned()),
        Just("a/".to_owned()),
    ]
}

fn any_non_canonical_address() -> impl Strategy<Value = String> {
    any_canonical_address()
        .prop_flat_map(|address| {
            prop_oneof![
                Just(format!("{address}.git")),
                Just(format!("https://{address}")),
                Just(format!("{address}/")),
                Just(address.to_uppercase()),
                Just(format!(" {address}")),
            ]
        })
        .prop_filter("the spelling is not canonical", |address| {
            orchestration_core::repository_address::parse_repository_address(
                address,
            )
            .as_deref()
                != Ok(address.as_str())
        })
}

fn git_accepts_branch(name: &str) -> Result<bool, TestCaseError> {
    let folders = create_held_folders().map_err(to_case_error)?;
    let output = Command::new("git")
        .args(["check-ref-format", "--branch", name])
        .env("GIT_CEILING_DIRECTORIES", folders.temporary.path())
        .current_dir(folders.temporary.path())
        .output()
        .map_err(to_case_error)?;
    Ok(output.status.success())
}

proptest! {
    #[test]
    fn test_ensure_plain_root_property_unsafe_roots_are_named(
        task_id in any_task_id(),
        lifetime in any_lifetime(),
        unsafe_root in any_unsafe_root(),
        is_cache_unsafe in any::<bool>(),
    ) {
        let mut request = request_for(task_id, "Fix", lifetime, Vec::new());
        if is_cache_unsafe {
            request.cache_root.clone_from(&unsafe_root);
        } else {
            request.worktrees_root.clone_from(&unsafe_root);
        }

        prop_assert_eq!(
            plan_worktree(&request),
            Err(WorktreeProblem::UnsafeRoot(unsafe_root))
        );
    }

    #[test]
    fn test_ensure_plain_root_property_cache_root_is_checked_first(
        task_id in any_task_id(),
        (cache_root, worktrees_root) in (any_unsafe_root(), any_unsafe_root()),
    ) {
        let request = WorktreeRequest {
            cache_root: cache_root.clone(),
            worktrees_root,
            ..request_for(
                task_id,
                "Fix",
                WorktreeLifetime::PerTask,
                Vec::new(),
            )
        };

        prop_assert_eq!(
            plan_worktree(&request),
            Err(WorktreeProblem::UnsafeRoot(cache_root))
        );
    }

    #[test]
    fn test_ensure_plain_root_property_plain_roots_hold_every_path(
        task_id in any_task_id(),
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        address in any_canonical_address(),
        folders in proptest::collection::vec("[a-zA-Z0-9 é_-]{1,8}", 1..4),
    ) {
        let root =
            PathBuf::from(format!("{PLAIN_ROOT}/{}", folders.join("/")));
        let request = WorktreeRequest {
            cache_root: root.join("cache"),
            worktrees_root: root.join("worktrees"),
            ..request_for(
                task_id,
                &title,
                lifetime,
                vec![repository_at(&address)],
            )
        };

        let plan = plan_or_fail(&request)?;

        prop_assert_eq!(
            plan.task_folder.parent(),
            Some(request.worktrees_root.as_path())
        );
        let planned = &plan.repositories[0];
        prop_assert_eq!(
            planned.cached_clone.parent(),
            Some(request.cache_root.as_path())
        );
    }

    #[test]
    fn test_plan_clone_url_property_default_branches_follow_git(
        task_id in any_task_id(),
        address in any_canonical_address(),
        default_branch in any_default_branch(),
    ) {
        let mut repository = repository_at(&address);
        repository.default_branch = default_branch.clone();
        let request = request_for(
            task_id,
            "Fix",
            WorktreeLifetime::PerTask,
            vec![repository],
        );

        let planned = plan_worktree(&request);

        let is_accepted_by_git = git_accepts_branch(&default_branch)?;
        let expected_problem =
            WorktreeProblem::InvalidDefaultBranch(default_branch);
        prop_assert_eq!(planned.is_ok(), is_accepted_by_git, "{:?}", planned);
        if !is_accepted_by_git {
            prop_assert_eq!(planned, Err(expected_problem));
        }
    }

    #[test]
    fn test_plan_clone_url_property_the_address_is_checked_first(
        task_id in any_task_id(),
        address in any_non_canonical_address(),
    ) {
        let mut repository = repository_at(&address);
        repository.default_branch = "-not-a-branch".to_owned();
        let request = request_for(
            task_id,
            "Fix",
            WorktreeLifetime::PerTask,
            vec![repository],
        );

        let expected = WorktreeProblem::InvalidRepositoryAddress(address);
        prop_assert_eq!(plan_worktree(&request), Err(expected));
    }

    #[test]
    fn test_plan_clone_url_property_the_template_gets_the_address_once(
        task_id in any_task_id(),
        address in any_canonical_address(),
        prefix in "[a-z]{1,6}://[a-z.]{1,10}/",
        suffix in "(\\.git)?",
    ) {
        let template = format!("{prefix}{ADDRESS_PLACEHOLDER}{suffix}");
        let clone_source =
            CloneSource::from_template(&template).map_err(to_case_error)?;
        let request = WorktreeRequest {
            clone_source,
            ..request_for(
                task_id,
                "Fix",
                WorktreeLifetime::PerTask,
                vec![repository_at(&address)],
            )
        };

        let plan = plan_or_fail(&request)?;

        let expected_url = format!("{prefix}{address}{suffix}");
        let arguments = &plan.repositories[0].clone_command.arguments;
        prop_assert_eq!(&arguments[3], &expected_url);
    }

    #[test]
    fn test_explain_clone_problem_property_names_the_address_as_written(
        task_id in any_task_id(),
        address in any_non_canonical_address(),
    ) {
        let request = request_for(task_id, "Fix", WorktreeLifetime::PerTask,
            vec![repository_at(&address)]);

        let expected = WorktreeProblem::InvalidRepositoryAddress(address);
        prop_assert_eq!(plan_worktree(&request), Err(expected));
    }

    #[test]
    fn test_explain_clone_problem_property_other_device_names_the_folder(
        task_id in any_task_id(),
        (runner_device, folder_device) in ("[0-9a-f]{32}", "[0-9a-f]{32}"),
        path in "(/[A-Za-z0-9_-][A-Za-z0-9 _-]{0,7}){1,3}",
    ) {
        prop_assume!(runner_device != folder_device);
        let folder = LocalFolder {
            device_id: DeviceId(folder_device),
            path,
        };
        let address = render_local_address(&folder).map_err(to_case_error)?;
        let request = WorktreeRequest {
            clone_source: CloneSource::standard()
                .on_device(DeviceId(runner_device)),
            ..request_for(
                task_id,
                "Fix",
                WorktreeLifetime::PerTask,
                vec![repository_at(&address)],
            )
        };

        let expected = WorktreeProblem::FolderOnAnotherDevice(address);
        prop_assert_eq!(plan_worktree(&request), Err(expected));
    }

    #[test]
    fn test_explain_clone_problem_property_the_first_bad_repository_is_named(
        task_id in any_task_id(),
        good_addresses in
            proptest::collection::btree_set(any_canonical_address(), 0..3),
        bad_address in any_non_canonical_address(),
        place in any::<proptest::sample::Index>(),
    ) {
        let good_names: std::collections::BTreeSet<String> = good_addresses
            .iter()
            .map(|address| {
                slugify(address.rsplit('/').next().unwrap_or_default())
            })
            .collect();
        prop_assume!(good_names.len() == good_addresses.len());
        let mut repositories: Vec<_> = good_addresses
            .iter()
            .map(|address| repository_at(address))
            .collect();
        let position = place.index(repositories.len() + 1);
        repositories.insert(position, repository_at(&bad_address));
        let request = request_for(
            task_id,
            "Fix",
            WorktreeLifetime::PerTask,
            repositories,
        );

        let planned = plan_worktree(&request);

        let expected = WorktreeProblem::InvalidRepositoryAddress(bad_address);
        prop_assert_eq!(planned, Err(expected));
    }
}
