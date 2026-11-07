use orchestration_core::repository_paths::{
    PATH_SEPARATOR, RepositoryPathProblem, normalize_file_path,
    normalize_folder_path, split_file_path,
};
use proptest::collection::vec;
use proptest::prelude::*;

const MAXIMUM_PARTS: usize = 5;
const HOSTILE_PATH: &str = "[a-zé ./\\\\\u{0}\u{7f}\n-]{0,16}";
const BACKSLASH: char = '\\';

fn path_part() -> impl Strategy<Value = String> {
    "[A-Za-zÀ-ÿ0-9_ ][A-Za-zÀ-ÿ0-9_. -]{0,8}"
}

fn relative_path() -> impl Strategy<Value = String> {
    vec(path_part(), 1..MAXIMUM_PARTS).prop_map(|parts| parts.join("/"))
}

fn problems_naming(path: &str) -> Vec<RepositoryPathProblem> {
    vec![
        RepositoryPathProblem::Absolute(path.to_owned()),
        RepositoryPathProblem::LeavesRepository(path.to_owned()),
        RepositoryPathProblem::InvalidCharacter(path.to_owned()),
    ]
}

fn insert_at(
    path: &str,
    index: prop::sample::Index,
    character: char,
) -> String {
    let characters: Vec<char> = path.chars().collect();
    let position = index.index(characters.len() + 1);
    let mut tainted = String::new();
    for character_before in &characters[..position] {
        tainted.push(*character_before);
    }
    tainted.push(character);
    for character_after in &characters[position..] {
        tainted.push(*character_after);
    }
    tainted
}

proptest! {
    #[test]
    fn test_repository_path_problem_fmt_property_quotes_the_path(
        path in any::<String>(),
    ) {
        let quoted_path = format!("{path:?}");

        for problem in problems_naming(&path) {
            prop_assert!(problem.to_string().contains(&quoted_path));
        }
    }

    #[test]
    fn test_repository_path_problem_fmt_property_tells_problems_apart(
        path in any::<String>(),
    ) {
        let mut messages = Vec::new();
        for problem in problems_naming(&path) {
            messages.push(problem.to_string());
        }
        messages.push(RepositoryPathProblem::EmptyFilePath.to_string());

        for (index, message) in messages.iter().enumerate() {
            prop_assert!(!messages[index + 1..].contains(message));
        }
    }

    #[test]
    fn test_repository_path_problem_fmt_property_names_the_given_path(
        path in relative_path(),
    ) {
        let absolute_path = format!("/{path}");

        let problem = normalize_folder_path(&absolute_path).err();

        let message = problem.as_ref().map(ToString::to_string);
        let quoted_path = format!("{absolute_path:?}");
        let names_path = message.is_some_and(|text| {
            text.contains(&quoted_path)
        });
        prop_assert!(names_path);
    }

    #[test]
    fn test_normalize_folder_path_property_keeps_parts_verbatim(
        parts in vec(path_part(), 0..MAXIMUM_PARTS),
    ) {
        let path = parts.join("/");

        prop_assert_eq!(normalize_folder_path(&path), Ok(path));
    }

    #[test]
    fn test_normalize_file_path_property_agrees_with_the_folder_path(
        path in HOSTILE_PATH,
    ) {
        let folder_path = normalize_folder_path(&path);

        let file_path = normalize_file_path(&path);

        let expected = match folder_path {
            Ok(normalized) if normalized.is_empty() => {
                Err(RepositoryPathProblem::EmptyFilePath)
            }
            other => other,
        };
        prop_assert_eq!(file_path, expected);
    }

    #[test]
    fn test_normalize_file_path_property_result_names_one_file(
        path in HOSTILE_PATH,
    ) {
        let Ok(file_path) = normalize_file_path(&path) else {
            return Ok(());
        };

        prop_assert!(!file_path.is_empty());
        prop_assert!(!file_path.starts_with(PATH_SEPARATOR));
        prop_assert!(!file_path.ends_with(PATH_SEPARATOR));
        let has_empty_part = file_path
            .split(PATH_SEPARATOR)
            .any(|part| part.is_empty() || part == "." || part == "..");
        prop_assert!(!has_empty_part);
    }

    #[test]
    fn test_split_file_path_property_name_is_the_last_part(
        path in relative_path(),
    ) {
        let Ok(file_path) = normalize_file_path(&path) else {
            return Err(TestCaseError::fail("a relative path is a file"));
        };

        let (_, name) = split_file_path(&file_path);

        prop_assert!(!name.is_empty());
        prop_assert!(!name.contains(PATH_SEPARATOR));
        prop_assert_eq!(Some(name), file_path.rsplit(PATH_SEPARATOR).next());
    }

    #[test]
    fn test_split_file_path_property_folder_is_a_normalized_folder(
        path in relative_path(),
    ) {
        let Ok(file_path) = normalize_file_path(&path) else {
            return Err(TestCaseError::fail("a relative path is a file"));
        };

        let (folder, _) = split_file_path(&file_path);

        prop_assert_eq!(normalize_folder_path(folder), Ok(folder.to_owned()));
        let expected_depth = file_path.matches(PATH_SEPARATOR).count();
        let folder_depth = if folder.is_empty() {
            0
        } else {
            folder.matches(PATH_SEPARATOR).count() + 1
        };
        prop_assert_eq!(folder_depth, expected_depth);
    }

    #[test]
    fn test_is_forbidden_character_property_backslash_anywhere_is_refused(
        path in relative_path(),
        position in any::<prop::sample::Index>(),
    ) {
        let tainted_path = insert_at(&path, position, BACKSLASH);

        let normalized = normalize_folder_path(&tainted_path);

        let expected = RepositoryPathProblem::InvalidCharacter(tainted_path);
        prop_assert_eq!(normalized, Err(expected));
    }

    #[test]
    fn test_is_forbidden_character_property_control_anywhere_is_refused(
        path in relative_path(),
        position in any::<prop::sample::Index>(),
        control in any::<char>()
            .prop_filter("control", |character| character.is_control()),
    ) {
        let tainted_path = insert_at(&path, position, control);

        let normalized = normalize_file_path(&tainted_path);

        let expected = RepositoryPathProblem::InvalidCharacter(tainted_path);
        prop_assert_eq!(normalized, Err(expected));
    }

    #[test]
    fn test_is_forbidden_character_property_other_characters_are_kept(
        path in relative_path(),
        position in any::<prop::sample::Index>(),
        character in any::<char>(),
    ) {
        prop_assume!(!character.is_control());
        prop_assume!(character != BACKSLASH && character != PATH_SEPARATOR);
        let widened_path = insert_at(&path, position, character);
        let is_dot_part = widened_path
            .split(PATH_SEPARATOR)
            .any(|part| part == "." || part == "..");
        prop_assume!(!is_dot_part);

        let normalized = normalize_folder_path(&widened_path);

        prop_assert_eq!(normalized, Ok(widened_path));
    }
}
