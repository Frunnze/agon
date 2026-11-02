use orchestration_core::repository_paths::{
    PATH_SEPARATOR, RepositoryPathProblem, normalize_file_path,
    normalize_folder_path, split_file_path,
};
use proptest::collection::vec;
use proptest::prelude::*;

fn safe_part() -> impl Strategy<Value = String> {
    "[A-Za-z0-9_][A-Za-z0-9_. -]{0,12}"
        .prop_filter("not a dot part", |part| part != "." && part != "..")
}

fn redundant_separator() -> impl Strategy<Value = String> {
    prop_oneof![
        Just("/".to_owned()),
        Just("//".to_owned()),
        Just("/./".to_owned()),
    ]
}

fn noisy_path(parts: &[String], separators: &[String]) -> String {
    let mut path = String::new();
    for (index, part) in parts.iter().enumerate() {
        if index > 0 {
            path.push_str(&separators[index % separators.len()]);
        }
        path.push_str(part);
    }
    path
}

fn is_normalized(path: &str) -> bool {
    path.is_empty()
        || path
            .split(PATH_SEPARATOR)
            .all(|part| !part.is_empty() && part != "." && part != "..")
}

proptest! {
    #[test]
    fn test_normalize_folder_path_property_drops_redundant_separators(
        parts in vec(safe_part(), 1..6),
        separators in vec(redundant_separator(), 1..4),
        trailing in prop_oneof![Just(""), Just("/")],
    ) {
        let path = format!("./{}{trailing}", noisy_path(&parts, &separators));

        let normalized = normalize_folder_path(&path);

        prop_assert_eq!(normalized, Ok(parts.join("/")));
    }

    #[test]
    fn test_normalize_folder_path_property_refuses_parent_parts(
        before in vec(safe_part(), 0..4),
        after in vec(safe_part(), 0..4),
    ) {
        let mut parts = before.clone();
        parts.push("..".to_owned());
        parts.extend(after);
        let path = parts.join("/");

        prop_assert_eq!(
            normalize_folder_path(&path),
            Err(RepositoryPathProblem::LeavesRepository(path.clone()))
        );
        prop_assert!(normalize_file_path(&path).is_err());
    }

    #[test]
    fn test_normalize_folder_path_property_refuses_absolute_paths(
        parts in vec(safe_part(), 0..4),
    ) {
        let path = format!("/{}", parts.join("/"));

        prop_assert_eq!(
            normalize_folder_path(&path),
            Err(RepositoryPathProblem::Absolute(path.clone()))
        );
    }

    #[test]
    fn test_normalize_folder_path_property_is_idempotent(
        path in any::<String>(),
    ) {
        if let Ok(normalized) = normalize_folder_path(&path) {
            prop_assert_eq!(
                normalize_folder_path(&normalized),
                Ok(normalized.clone())
            );
        }
    }

    #[test]
    fn test_normalize_folder_path_fuzz_never_leaves_the_repository(
        path in any::<String>(),
    ) {
        match normalize_folder_path(&path) {
            Ok(normalized) => {
                prop_assert!(is_normalized(&normalized), "{normalized:?}");
                prop_assert!(!normalized.starts_with(PATH_SEPARATOR));
                prop_assert!(!normalized.contains('\\'));
                prop_assert!(!normalized.chars().any(char::is_control));
            }
            Err(problem) => prop_assert!(!problem.to_string().is_empty()),
        }
    }

    #[test]
    fn test_normalize_file_path_property_refuses_the_root(
        dots in vec(prop_oneof![Just("."), Just("")], 0..5),
    ) {
        let path = format!("./{}", dots.join("/"));

        prop_assert_eq!(
            normalize_file_path(&path),
            Err(RepositoryPathProblem::EmptyFilePath)
        );
    }

    #[test]
    fn test_normalize_folder_path_property_refuses_control_characters(
        prefix in safe_part(),
        character in prop_oneof![
            Just('\0'), Just('\n'), Just('\u{7f}'), Just('\\'),
        ],
        suffix in safe_part(),
    ) {
        let path = format!("{prefix}{character}{suffix}");

        prop_assert_eq!(
            normalize_folder_path(&path),
            Err(RepositoryPathProblem::InvalidCharacter(path.clone()))
        );
    }

    #[test]
    fn test_split_file_path_property_joins_back_to_the_path(
        parts in vec(safe_part(), 1..6),
    ) {
        let path = parts.join("/");

        let (folder, name) = split_file_path(&path);

        prop_assert_eq!(name, parts[parts.len() - 1].as_str());
        let joined = if folder.is_empty() {
            name.to_owned()
        } else {
            format!("{folder}/{name}")
        };
        prop_assert_eq!(joined, path);
    }
}
