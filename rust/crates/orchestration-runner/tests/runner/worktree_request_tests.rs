use std::path::PathBuf;

use chrono::Weekday;
use orchestration_core::task::{Schedule, Task, TimeOfDay};
use orchestration_core::workspace::AgentAccess;
use orchestration_hub::clone_source::CloneSource;
use orchestration_hub::worktree_plan::WorktreeLifetime;
use orchestration_runner::runner_configuration::WorktreeRoots;
use orchestration_runner::worktree_request::describe_worktree_request;
use proptest::collection::vec;
use proptest::option;
use proptest::prelude::*;

use crate::assignments::{assignment_for, claude_task};
use crate::git_support::repository_at;
use crate::support::to_case_error;

fn any_schedule() -> impl Strategy<Value = Schedule> {
    let at = TimeOfDay { hour: 2, minute: 0 };
    prop_oneof![
        Just(Schedule::Hour { minute: 15 }),
        Just(Schedule::Day { at }),
        Just(Schedule::Week {
            on: Weekday::Mon,
            at,
        }),
    ]
}

proptest! {
    #[test]
    fn test_describe_worktree_request_property_gives_jobs_a_run_folder(
        schedule in option::of(any_schedule()),
        run_number in 1_u32..1000,
        title in "[a-zA-Z ]{1,30}",
        origins in vec("/origins/[a-z]{1,8}", 0..3),
        template in "file:///[a-z]{1,8}/\\{address\\}(\\.git)?",
    ) {
        let repositories: Vec<_> = origins
            .iter()
            .map(|origin| {
                repository_at(&PathBuf::from(origin), AgentAccess::ReadOnly)
            })
            .collect();
        let task = Task {
            schedule,
            ..claude_task(7, &title)
        };
        let mut assignment = assignment_for(task, None, repositories, 7)
            .map_err(to_case_error)?;
        assignment.run.number = run_number;
        let roots = WorktreeRoots {
            cache_root: PathBuf::from("/runner/cache"),
            worktrees_root: PathBuf::from("/runner/worktrees"),
        };

        let clone_source = CloneSource::from_template(&template)
            .map_err(to_case_error)?;

        let request =
            describe_worktree_request(&assignment, &roots, &clone_source);

        let expected_lifetime = match schedule {
            Some(_) => WorktreeLifetime::PerJobRun { run_number },
            None => WorktreeLifetime::PerTask,
        };
        prop_assert_eq!(request.lifetime, expected_lifetime);
        prop_assert_eq!(request.task_id, assignment.task.id);
        prop_assert_eq!(&request.task_title, &title);
        let project_repositories = assignment
            .project
            .as_ref()
            .map(|project| project.repositories.clone());
        prop_assert_eq!(Some(request.repositories), project_repositories);
        prop_assert_eq!(&request.cache_root, &roots.cache_root);
        prop_assert_eq!(&request.worktrees_root, &roots.worktrees_root);
        prop_assert_eq!(&request.clone_source, &clone_source);
    }
}
