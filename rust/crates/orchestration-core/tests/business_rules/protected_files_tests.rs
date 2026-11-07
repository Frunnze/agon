use orchestration_core::protected_files::{
    MAXIMUM_PATTERN_COUNT, MAXIMUM_PATTERN_LENGTH, ProtectedFiles,
    ProtectedPatternProblem, validate_protected_files,
};
use orchestration_core::protected_paths::is_protected_path;
use orchestration_core::workspace::Workspace;
use proptest::collection::vec;
use proptest::prelude::*;

const ENV_FILE_NAME: &str = ".env";
const ENV_VARIANTS_PATTERN: &str = ".env.*";
const FORBIDDEN_CHARACTERS: [char; 5] = ['"', '\'', '\\', '(', ')'];
const SAMPLE_HOME_FOLDER_NAME: &str = "home";

fn sample_home() -> String {
    let home_folder = std::env::temp_dir().join(SAMPLE_HOME_FOLDER_NAME);
    home_folder.display().to_string()
}

fn folder_name() -> impl Strategy<Value = String> {
    "[a-z][a-z0-9_-]{0,8}"
}

fn folder_path() -> impl Strategy<Value = String> {
    vec(folder_name(), 0..5).prop_map(|names| {
        let mut path = String::new();
        for name in names {
            path.push('/');
            path.push_str(&name);
        }
        path
    })
}

fn only_patterns(patterns: &[&str]) -> ProtectedFiles {
    ProtectedFiles {
        patterns: patterns.iter().map(ToString::to_string).collect(),
    }
}

proptest! {
    #[test]
    fn test_is_protected_path_property_env_file_matches_at_any_depth(
        folders in folder_path(),
        home in folder_path(),
    ) {
        let protected = ProtectedFiles::default();
        let path = format!("{folders}/{ENV_FILE_NAME}");

        prop_assert!(is_protected_path(&protected, &path, &home));
    }

    #[test]
    fn test_is_protected_path_property_env_variants_follow_the_patterns(
        folders in folder_path(),
        suffix in "[a-z]{1,8}",
    ) {
        let variant = format!("{folders}/{ENV_FILE_NAME}.{suffix}");
        let only_env_file = only_patterns(&[ENV_FILE_NAME]);
        let only_variants = only_patterns(&[ENV_VARIANTS_PATTERN]);
        let env_file = format!("{folders}/{ENV_FILE_NAME}");
        let home = sample_home();

        prop_assert!(!is_protected_path(&only_env_file, &variant, &home));
        prop_assert!(is_protected_path(&only_variants, &variant, &home));
        prop_assert!(!is_protected_path(&only_variants, &env_file, &home));
    }

    #[test]
    fn test_is_protected_path_property_names_never_match_inside_words(
        folders in folder_path(),
        prefix in "[a-z]{1,4}",
        suffix in "[a-z]{1,4}",
    ) {
        let protected = only_patterns(&[ENV_FILE_NAME]);
        let before = format!("{folders}/{prefix}{ENV_FILE_NAME}");
        let after = format!("{folders}/{ENV_FILE_NAME}{suffix}");
        let home = sample_home();

        prop_assert!(!is_protected_path(&protected, &before, &home));
        prop_assert!(!is_protected_path(&protected, &after, &home));
    }

    #[test]
    fn test_is_protected_path_property_protects_everything_inside(
        folders in folder_path(),
        inside in folder_path(),
    ) {
        let protected = only_patterns(&[ENV_FILE_NAME]);
        let path = format!("{folders}/{ENV_FILE_NAME}{inside}");

        prop_assert!(is_protected_path(&protected, &path, &sample_home()));
    }

    #[test]
    fn test_is_protected_path_property_home_patterns_match_only_under_home(
        home in folder_path().prop_filter("not the root", |home| {
            !home.is_empty()
        }),
        secret in folder_name(),
        inside in folder_path(),
    ) {
        let pattern = format!("~/.{secret}");
        let protected = ProtectedFiles { patterns: vec![pattern] };
        let under_home = format!("{home}/.{secret}{inside}");
        let elsewhere = format!("/elsewhere{home}/.{secret}{inside}");

        prop_assert!(is_protected_path(&protected, &under_home, &home));
        prop_assert!(!is_protected_path(&protected, &elsewhere, &home));
    }

    #[test]
    fn test_is_protected_path_property_absolute_patterns_match_from_root(
        folders in folder_path(),
        name in folder_name(),
    ) {
        let pattern = format!("/secrets/{name}");
        let protected = ProtectedFiles { patterns: vec![pattern] };
        let at_root = format!("/secrets/{name}{folders}");
        let deeper = format!("/deeper/secrets/{name}");
        let home = sample_home();

        prop_assert!(is_protected_path(&protected, &at_root, &home));
        prop_assert!(!is_protected_path(&protected, &deeper, &home));
    }

    #[test]
    fn test_is_protected_path_property_double_star_spans_folders(
        folders in folder_path(),
        name in folder_name(),
    ) {
        let protected = only_patterns(&["~/.config/**/token.json"]);
        let home = sample_home();
        let path = format!("{home}/.config{folders}/token.json");
        let other = format!("{home}/.config{folders}/{name}.txt");

        prop_assert!(is_protected_path(&protected, &path, &home));
        prop_assert!(!is_protected_path(&protected, &other, &home));
    }

    #[test]
    fn test_is_protected_path_property_ignores_letter_case(
        folders in folder_path(),
    ) {
        let protected = ProtectedFiles::default();
        let path = format!("{folders}/.ENV");

        prop_assert!(is_protected_path(&protected, &path, &sample_home()));
    }

    #[test]
    fn test_is_protected_path_property_empty_list_protects_nothing(
        folders in folder_path(),
        name in folder_name(),
    ) {
        let protected = ProtectedFiles { patterns: Vec::new() };
        let path = format!("{folders}/{name}");

        prop_assert!(!is_protected_path(&protected, &path, &sample_home()));
    }

    #[test]
    fn test_is_protected_path_property_never_panics_on_any_text(
        patterns in vec(any::<String>(), 0..4),
        path in any::<String>(),
        home in any::<String>(),
    ) {
        let protected = ProtectedFiles { patterns };

        let _ = is_protected_path(&protected, &path, &home);
    }

    #[test]
    fn test_validate_protected_files_property_never_panics_on_any_text(
        patterns in vec(any::<String>(), 0..4),
    ) {
        let protected = ProtectedFiles { patterns };

        let _ = validate_protected_files(&protected);
    }

    #[test]
    fn test_validate_protected_files_property_accepts_plain_patterns(
        names in vec(folder_name(), 1..6),
    ) {
        let mut patterns = Vec::new();
        for name in names {
            let pattern = format!("~/.{name}");
            if !patterns.contains(&pattern) {
                patterns.push(pattern);
            }
        }
        let protected = ProtectedFiles { patterns };

        prop_assert_eq!(validate_protected_files(&protected), Ok(()));
    }

    #[test]
    fn test_validate_protected_files_property_refuses_quotes_and_brackets(
        name in folder_name(),
        position in 0usize..FORBIDDEN_CHARACTERS.len(),
    ) {
        let character = FORBIDDEN_CHARACTERS[position];
        let pattern = format!("{name}{character}");
        let protected = ProtectedFiles { patterns: vec![pattern.clone()] };

        prop_assert_eq!(
            validate_protected_files(&protected),
            Err(ProtectedPatternProblem::ForbiddenCharacter {
                pattern,
                character,
            })
        );
    }

    #[test]
    fn test_validate_protected_files_property_refuses_duplicates(
        name in folder_name(),
    ) {
        let pattern = format!("~/.{name}");
        let protected = ProtectedFiles {
            patterns: vec![pattern.clone(), pattern.clone()],
        };

        prop_assert_eq!(
            validate_protected_files(&protected),
            Err(ProtectedPatternProblem::Duplicate {
                pattern: pattern.clone(),
                earlier_pattern: pattern,
            })
        );
    }

    #[test]
    fn test_validate_protected_files_property_refuses_long_patterns(
        extra in 1usize..20,
    ) {
        let pattern = "a".repeat(MAXIMUM_PATTERN_LENGTH + extra);
        let length = pattern.chars().count();
        let protected = ProtectedFiles { patterns: vec![pattern] };

        prop_assert_eq!(
            validate_protected_files(&protected),
            Err(ProtectedPatternProblem::TooLong { length })
        );
    }

    #[test]
    fn test_protected_files_property_round_trips_through_json(
        names in vec(folder_name(), 0..6),
    ) {
        let protected = ProtectedFiles { patterns: names };
        let text = serde_json::to_string(&protected);
        prop_assert!(text.is_ok());
        let text = text.unwrap_or_default();

        let read_back: Result<ProtectedFiles, _> =
            serde_json::from_str(&text);

        prop_assert_eq!(read_back.ok(), Some(protected));
    }
}

#[test]
fn test_default_protected_files_property_defaults_are_valid() {
    let defaults = ProtectedFiles::default();

    assert_eq!(validate_protected_files(&defaults), Ok(()));
    assert!(defaults.patterns.contains(&ENV_FILE_NAME.to_string()));
    assert!(
        defaults
            .patterns
            .contains(&ENV_VARIANTS_PATTERN.to_string())
    );
    assert!(defaults.patterns.contains(&"~/.ssh".to_string()));
}

#[test]
fn test_default_protected_files_property_defaults_round_trip() {
    let defaults = ProtectedFiles::default();
    let text = serde_json::to_string(&defaults).unwrap_or_default();

    let read_back: Result<ProtectedFiles, _> = serde_json::from_str(&text);

    assert_eq!(read_back.ok(), Some(defaults));
}

#[test]
fn test_workspace_property_saved_without_the_list_reads_the_defaults() {
    let saved = serde_json::json!({
        "id": "00000000-0000-0000-0000-000000000001",
        "name": "acme",
        "app_server_address": "http://127.0.0.1:7070",
    });

    let workspace: Result<Workspace, _> = serde_json::from_value(saved);

    let protected_files = workspace.ok().map(|read| read.protected_files);
    assert_eq!(protected_files, Some(ProtectedFiles::default()));
}

#[test]
fn test_validate_protected_files_property_refuses_patterns_naming_nothing() {
    for pattern in ["~", "/", ".", "~/", "./"] {
        let protected = only_patterns(&[pattern]);
        let expected = ProtectedPatternProblem::NamesNothing {
            pattern: pattern.to_string(),
        };

        assert_eq!(validate_protected_files(&protected), Err(expected));
    }
}

#[test]
fn test_validate_protected_files_property_refuses_parent_folders() {
    let protected = only_patterns(&["~/../secret"]);
    let expected = ProtectedPatternProblem::ParentFolder {
        pattern: "~/../secret".to_string(),
    };

    assert_eq!(validate_protected_files(&protected), Err(expected));
}

#[test]
fn test_validate_protected_files_property_refuses_too_many_patterns() {
    let mut patterns = Vec::new();
    for index in 0..=MAXIMUM_PATTERN_COUNT {
        patterns.push(format!("secret-{index}"));
    }
    let count = patterns.len();
    let protected = ProtectedFiles { patterns };

    assert_eq!(
        validate_protected_files(&protected),
        Err(ProtectedPatternProblem::TooMany { count })
    );
}

#[test]
fn test_validate_protected_files_property_refuses_surrounding_space() {
    let protected = only_patterns(&[" ~/.ssh"]);
    let expected = ProtectedPatternProblem::SurroundingSpace {
        pattern: " ~/.ssh".to_string(),
    };

    assert_eq!(validate_protected_files(&protected), Err(expected));
}
