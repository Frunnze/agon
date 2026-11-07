use std::fs;
use std::os::unix::fs::symlink;
use std::path::{Component, Path, PathBuf};

use orchestration_hub::clone_locks::CloneLocks;
use orchestration_hub::worktree_plan::WorktreePlan;
use orchestration_hub::worktrees::{WorktreeError, create_worktrees};
use proptest::prelude::*;

use crate::git_support::RunnerFolders;
use crate::held_folders::to_case_error;
use crate::worktree_folders::{
    CaseResult, GIT_CASES, create, create_origins, plan_task, prepare_folders,
};
use crate::worktree_support::{any_hostile_title, any_lifetime};

const TASK_NUMBER: u128 = 0x8888_0000_0000_4000_8000_0000_0000_0008;
const KEPT_FILE_NAME: &str = "kept.txt";
const REAL_ROOTS_FOLDER: &str = "real-roots";
const LINKED_ROOTS_FOLDER: &str = "linked-roots";
const CACHE_FOLDER_NAME: &str = "cache";
const WORKTREES_FOLDER_NAME: &str = "worktrees";

fn blocked_path(
    plan: &WorktreePlan,
    is_worktree_blocked: bool,
) -> CaseResult<PathBuf> {
    if !is_worktree_blocked {
        if let Some(parent) = plan.task_folder.parent() {
            fs::create_dir_all(parent).map_err(to_case_error)?;
        }
        return Ok(plan.task_folder.clone());
    }
    fs::create_dir_all(&plan.task_folder).map_err(to_case_error)?;
    Ok(plan.repositories[0].worktree.clone())
}

fn expect_blocked(plan: &WorktreePlan, blocked: &Path) -> CaseResult<()> {
    let creation = create_worktrees(plan, &CloneLocks::default());
    let Err(WorktreeError::BlockedFolder(path)) = creation else {
        return Err(to_case_error(format!("{creation:?}")));
    };
    if path != blocked {
        let problem =
            format!("{} is not {}", path.display(), blocked.display());
        return Err(to_case_error(problem));
    }
    Ok(())
}

fn link_roots(folders: RunnerFolders) -> CaseResult<RunnerFolders> {
    let real = folders.temporary.path().join(REAL_ROOTS_FOLDER);
    let linked = folders.temporary.path().join(LINKED_ROOTS_FOLDER);
    fs::create_dir_all(&real).map_err(to_case_error)?;
    symlink(&real, &linked).map_err(to_case_error)?;
    Ok(RunnerFolders {
        cache_root: linked.join(CACHE_FOLDER_NAME),
        worktrees_root: linked.join(WORKTREES_FOLDER_NAME),
        temporary: folders.temporary,
    })
}

fn dot_roots(folders: RunnerFolders) -> RunnerFolders {
    let dotted = folders.temporary.path().join(".");
    RunnerFolders {
        cache_root: dotted.join(CACHE_FOLDER_NAME),
        worktrees_root: dotted.join(WORKTREES_FOLDER_NAME),
        temporary: folders.temporary,
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GIT_CASES))]

    #[test]
    fn test_ensure_not_blocked_property_a_dangling_link_blocks(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        is_worktree_blocked in any::<bool>(),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan =
            plan_task(&folders, TASK_NUMBER, &title, lifetime, &origins)?;
        let blocked = blocked_path(&plan, is_worktree_blocked)?;
        let missing_target = folders.temporary.path().join("nowhere");
        symlink(&missing_target, &blocked).map_err(to_case_error)?;

        expect_blocked(&plan, &blocked)?;

        prop_assert!(!missing_target.exists());
    }

    #[test]
    fn test_ensure_not_blocked_property_a_linked_folder_is_left_alone(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        is_worktree_blocked in any::<bool>(),
        content in "[a-z]{0,20}",
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan =
            plan_task(&folders, TASK_NUMBER, &title, lifetime, &origins)?;
        let blocked = blocked_path(&plan, is_worktree_blocked)?;
        let target = folders.temporary.path().join("target");
        fs::create_dir_all(&target).map_err(to_case_error)?;
        fs::write(target.join(KEPT_FILE_NAME), &content)
            .map_err(to_case_error)?;
        symlink(&target, &blocked).map_err(to_case_error)?;

        expect_blocked(&plan, &blocked)?;

        let names: Vec<_> = fs::read_dir(&target)
            .map_err(to_case_error)?
            .filter_map(Result::ok)
            .map(|entry| entry.file_name())
            .collect();
        prop_assert_eq!(names, vec![std::ffi::OsString::from(KEPT_FILE_NAME)]);
    }

    #[test]
    fn test_ensure_not_blocked_property_a_file_keeps_its_content(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
        is_worktree_blocked in any::<bool>(),
        content in "[a-z]{0,20}",
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan =
            plan_task(&folders, TASK_NUMBER, &title, lifetime, &origins)?;
        let blocked = blocked_path(&plan, is_worktree_blocked)?;
        fs::write(&blocked, &content).map_err(to_case_error)?;

        expect_blocked(&plan, &blocked)?;

        let kept = fs::read_to_string(&blocked).map_err(to_case_error)?;
        prop_assert_eq!(kept, content);
    }

    #[test]
    fn test_resolve_folder_property_mounts_name_the_folders_behind_links(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let linked_folders = link_roots(folders)?;
        let plan = plan_task(
            &linked_folders,
            TASK_NUMBER,
            &title,
            lifetime,
            &origins,
        )?;

        let prepared = create(&plan)?;

        let real_task_folder =
            plan.task_folder.canonicalize().map_err(to_case_error)?;
        prop_assert_eq!(&prepared.mounts.task_folder, &real_task_folder);
        let all_mounts = prepared
            .mounts
            .git_directories
            .iter()
            .chain(std::iter::once(&prepared.mounts.task_folder));
        for mount in all_mounts {
            let is_linked = mount.components().any(|component| {
                component == Component::Normal(LINKED_ROOTS_FOLDER.as_ref())
            });
            prop_assert!(!is_linked, "{:?}", mount);
            prop_assert!(mount.is_dir());
        }
    }

    #[test]
    fn test_resolve_folder_property_mounted_folders_are_absolute_and_real(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plan =
            plan_task(&folders, TASK_NUMBER, &title, lifetime, &origins)?;

        let prepared = create(&plan)?;

        let all_mounts = prepared
            .mounts
            .git_directories
            .iter()
            .chain(std::iter::once(&prepared.mounts.task_folder));
        for mount in all_mounts {
            prop_assert!(mount.is_absolute());
            let resolved = mount.canonicalize().map_err(to_case_error)?;
            prop_assert_eq!(&resolved, mount);
        }
    }

    #[test]
    fn test_resolve_folder_property_dotted_roots_mount_plain_folders(
        title in any_hostile_title(),
        lifetime in any_lifetime(),
    ) {
        let folders = prepare_folders()?;
        let origins = create_origins(&folders, 1)?;
        let plain_worktrees_root = folders.worktrees_root.clone();
        let dotted = dot_roots(folders);
        let plan =
            plan_task(&dotted, TASK_NUMBER, &title, lifetime, &origins)?;

        let prepared = create(&plan)?;

        let folder_name = plan.task_folder.file_name().unwrap_or_default();
        let plain_task_folder = plain_worktrees_root
            .join(folder_name)
            .canonicalize()
            .map_err(to_case_error)?;
        prop_assert_eq!(prepared.mounts.task_folder, plain_task_folder);
    }
}
