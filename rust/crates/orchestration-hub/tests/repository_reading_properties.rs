mod git_support;
mod repository_fixture;

use git_support::TestResult;
use orchestration_core::repository_files::RepositoryEntryKind;
use orchestration_hub::repository_reading::RepositoryReadError;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestCaseError, TestRunner};
use repository_fixture::build_fixture;

const PATH_CASES: u32 = 48;

fn path_part() -> impl Strategy<Value = String> {
    prop_oneof![
        Just("..".to_owned()),
        Just(".".to_owned()),
        Just(String::new()),
        Just("src".to_owned()),
        Just("auth".to_owned()),
        Just("redirect.ts".to_owned()),
        Just("source-link".to_owned()),
        Just("outside".to_owned()),
        Just("etc".to_owned()),
        Just("passwd".to_owned()),
        "[a-z]{1,6}",
    ]
}

fn candidate_path() -> impl Strategy<Value = String> {
    (any::<bool>(), vec(path_part(), 1..6)).prop_map(|(is_absolute, parts)| {
        let joined = parts.join("/");
        if is_absolute {
            format!("/{joined}")
        } else {
            joined
        }
    })
}

fn has_parent_part(path: &str) -> bool {
    path.split('/').any(|part| part == "..")
}

fn new_runner() -> TestRunner {
    TestRunner::new(Config::with_cases(PATH_CASES))
}

#[test]
fn test_read_file_property_reads_only_inside_the_repository() -> TestResult<()>
{
    let fixture = build_fixture()?;
    let reader = &fixture.reader;

    new_runner().run(&candidate_path(), |path| {
        let outcome = reader.read_file("main", &path);
        let must_refuse = path.starts_with('/') || has_parent_part(&path);
        if must_refuse {
            prop_assert!(matches!(outcome, Err(RepositoryReadError::Path(_))));
        }
        if let Ok(file) = outcome {
            prop_assert!(!file.path.starts_with('/'));
            prop_assert!(!has_parent_part(&file.path));
            prop_assert!(!file.path.starts_with("source-link/"));
        }
        Ok(())
    })?;
    Ok(())
}

#[test]
fn test_list_folder_property_lists_only_real_folders() -> TestResult<()> {
    let fixture = build_fixture()?;
    let reader = &fixture.reader;
    let task_branch = fixture.task_branch().to_owned();

    new_runner().run(&candidate_path(), |path| {
        for branch in ["main", task_branch.as_str()] {
            let outcome = reader.list_folder(branch, &path);
            let must_refuse = path.starts_with('/') || has_parent_part(&path);
            if must_refuse && outcome.is_ok() {
                let reason = format!("{path:?} was listed on {branch}");
                return Err(TestCaseError::fail(reason));
            }
            if let Ok(entries) = outcome {
                let has_sizes = entries.iter().all(|entry| {
                    (entry.kind == RepositoryEntryKind::Folder)
                        == entry.size.is_none()
                });
                prop_assert!(has_sizes);
            }
        }
        Ok(())
    })?;
    Ok(())
}
