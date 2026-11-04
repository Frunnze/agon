mod git_support;
mod repository_fixture;

use git_support::{TestResult, prepare_runner_folders, run_git};
use orchestration_core::repository_files::{
    FilePreview, RepositoryEntry, RepositoryEntryKind,
};
use orchestration_hub::file_previews::MAXIMUM_TEXT_PREVIEW_BYTES;
use orchestration_hub::repository_reading::{
    RepositoryReadError, RepositoryReader,
};
use repository_fixture::{REDIRECT_SOURCE, TASK_ONLY_SOURCE, build_fixture};

fn names(entries: &[RepositoryEntry]) -> Vec<&str> {
    entries.iter().map(|entry| entry.name.as_str()).collect()
}

fn text_of(preview: &FilePreview) -> Option<&str> {
    match preview {
        FilePreview::Text { text } => Some(text),
        _ => None,
    }
}

#[test]
fn test_list_branches_groups_repository_and_task_branches() -> TestResult<()> {
    let fixture = build_fixture()?;

    let branches = fixture.reader.list_branches()?;

    assert!(branches.branches.contains(&"main".to_owned()));
    assert!(branches.branches.contains(&"release".to_owned()));
    assert_eq!(branches.task_branches, [fixture.task_branch()]);
    assert!(
        branches
            .branches
            .iter()
            .all(|name| !name.starts_with("task/"))
    );
    Ok(())
}

#[test]
fn test_list_folder_shows_folders_first_with_sizes() -> TestResult<()> {
    let fixture = build_fixture()?;

    let root = fixture.reader.list_folder("main", "")?;
    let assets = fixture.reader.list_folder("main", "assets")?;

    assert_eq!(
        names(&root),
        [
            "assets",
            "notes",
            "src",
            "outside",
            "README.md",
            "source-link"
        ]
    );
    assert_eq!(root[0].kind, RepositoryEntryKind::Folder);
    assert_eq!(root[0].size, None);
    assert_eq!(root[3].kind, RepositoryEntryKind::Link);
    assert_eq!(names(&assets), ["data.bin", "icon.png", "onboarding.mp4"]);
    assert_eq!(assets[1].size, Some(33));
    Ok(())
}

#[test]
fn test_read_file_reads_text_on_main_and_on_the_task_branch() -> TestResult<()>
{
    let fixture = build_fixture()?;
    let task_branch = fixture.task_branch();

    let on_main = fixture.reader.read_file("main", "src/auth/redirect.ts")?;
    let on_task = fixture.reader.read_file(task_branch, "src/auth/fix.ts")?;
    let missing_on_main = fixture.reader.read_file("main", "src/auth/fix.ts");
    let task_folder = fixture.reader.list_folder(task_branch, "src/auth")?;

    assert_eq!(text_of(&on_main.preview), Some(REDIRECT_SOURCE));
    assert_eq!(on_main.size, REDIRECT_SOURCE.len() as u64);
    assert_eq!(text_of(&on_task.preview), Some(TASK_ONLY_SOURCE));
    assert!(matches!(
        missing_on_main,
        Err(RepositoryReadError::NotFound(_))
    ));
    assert_eq!(names(&task_folder), ["fix.ts", "redirect.ts"]);
    Ok(())
}

#[test]
fn test_read_file_previews_images_and_limits_large_files() -> TestResult<()> {
    let fixture = build_fixture()?;

    let icon = fixture.reader.read_file("main", "assets/icon.png")?;
    let binary = fixture.reader.read_file("main", "assets/data.bin")?;
    let large = fixture.reader.read_file("main", "notes/large.txt")?;
    let huge = fixture.reader.read_file("main", "assets/onboarding.mp4")?;

    assert!(matches!(
        icon.preview,
        FilePreview::Image {
            width: 2,
            height: 3,
            ..
        }
    ));
    assert_eq!(binary.preview, FilePreview::Binary);
    assert_eq!(large.preview, FilePreview::TooLarge);
    assert_eq!(large.size, MAXIMUM_TEXT_PREVIEW_BYTES + 1);
    assert_eq!(huge.preview, FilePreview::TooLarge);
    Ok(())
}

#[test]
fn test_read_file_never_follows_links() -> TestResult<()> {
    let fixture = build_fixture()?;

    let outside = fixture.reader.read_file("main", "outside")?;
    let through_link = fixture
        .reader
        .read_file("main", "source-link/auth/redirect.ts");
    let link_folder = fixture.reader.list_folder("main", "source-link");

    assert_eq!(outside.preview, FilePreview::Link);
    assert!(matches!(
        through_link,
        Err(RepositoryReadError::NotFound(_))
    ));
    assert!(matches!(
        link_folder,
        Err(RepositoryReadError::NotAFolder(_))
    ));
    Ok(())
}

#[test]
fn test_reading_refuses_paths_that_leave_the_repository() -> TestResult<()> {
    let fixture = build_fixture()?;

    let parent = fixture.reader.read_file("main", "../app/README.md");
    let hidden_parent = fixture.reader.read_file("main", "src/../README.md");
    let absolute = fixture.reader.read_file("main", "/etc/passwd");
    let parent_folder = fixture.reader.list_folder("main", "src/..");
    let absolute_folder = fixture.reader.list_folder("main", "/");

    for refusal in [parent, hidden_parent, absolute] {
        assert!(matches!(refusal, Err(RepositoryReadError::Path(_))));
    }
    for refusal in [parent_folder, absolute_folder] {
        assert!(matches!(refusal, Err(RepositoryReadError::Path(_))));
    }
    Ok(())
}

#[test]
fn test_reading_refuses_unknown_branches_and_folders() -> TestResult<()> {
    let fixture = build_fixture()?;

    let unknown = fixture.reader.list_folder("HEAD~1", "");
    let option_like = fixture.reader.read_file("--output=x", "a");
    let folder_as_file = fixture.reader.read_file("main", "src");
    let file_as_folder = fixture.reader.list_folder("main", "README.md");

    assert!(matches!(
        unknown,
        Err(RepositoryReadError::UnknownBranch(_))
    ));
    assert!(matches!(
        option_like,
        Err(RepositoryReadError::UnknownBranch(_))
    ));
    assert!(matches!(
        folder_as_file,
        Err(RepositoryReadError::NotAFile(_))
    ));
    assert!(matches!(
        file_as_folder,
        Err(RepositoryReadError::NotAFolder(_))
    ));
    Ok(())
}

#[test]
fn test_reading_never_writes_to_the_repository() -> TestResult<()> {
    let fixture = build_fixture()?;
    let repository = fixture.plan.repositories.first().ok_or("none")?;
    let clone = repository.cached_clone.clone();
    let before = run_git(&clone, &["for-each-ref"])?;
    let status_before = run_git(&clone, &["status", "--porcelain"])?;

    fixture.reader.list_branches()?;
    fixture.reader.list_folder("main", "src/auth")?;
    fixture.reader.read_file("main", "assets/icon.png")?;

    assert_eq!(run_git(&clone, &["for-each-ref"])?, before);
    assert_eq!(run_git(&clone, &["status", "--porcelain"])?, status_before);
    Ok(())
}

#[test]
fn test_open_refuses_a_folder_without_a_clone() -> TestResult<()> {
    let folders = prepare_runner_folders()?;

    let opened = RepositoryReader::open(&folders.cache_root.join("missing"));

    assert!(matches!(opened, Err(RepositoryReadError::NoCopy)));
    Ok(())
}
