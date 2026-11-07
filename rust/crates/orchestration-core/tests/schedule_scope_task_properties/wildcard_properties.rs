use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::protected_paths::is_protected_path;
use proptest::prelude::*;

const HOME: &str = "<home>";
const ANY_CHARACTERS: &str = "*";
const DOUBLED_ANY_CHARACTERS: &str = "**";

fn name_glob() -> impl Strategy<Value = String> {
    "[ab?]{0,3}\\*[ab?*]{0,4}[ab]"
}

fn name() -> impl Strategy<Value = String> {
    "[abAB]{1,8}"
}

fn protects(glob: &str, name: &str) -> bool {
    let protected = ProtectedFiles {
        patterns: vec![format!("/{glob}")],
    };
    is_protected_path(&protected, &format!("/{name}"), HOME)
}

fn reversed(text: &str) -> String {
    text.chars().rev().collect()
}

proptest! {
    #[test]
    fn test_matches_wildcards_property_doubled_stars_match_like_one(
        glob in name_glob(),
        name in name(),
    ) {
        let doubled = glob.replace(ANY_CHARACTERS, DOUBLED_ANY_CHARACTERS);

        prop_assert_eq!(protects(&doubled, &name), protects(&glob, &name));
    }

    #[test]
    fn test_matches_wildcards_property_reversing_both_keeps_the_verdict(
        glob in name_glob(),
        name in name(),
    ) {
        let reversed_glob = reversed(&glob);
        let reversed_name = reversed(&name);

        prop_assert_eq!(
            protects(&reversed_glob, &reversed_name),
            protects(&glob, &name)
        );
    }

    #[test]
    fn test_matches_wildcards_property_a_lone_star_matches_every_name(
        name in "[^/]{1,12}",
        prefix in "[ab]{0,3}",
    ) {
        prop_assume!(name != "." && name != "..");
        let starts_with_prefix = name
            .to_ascii_lowercase()
            .starts_with(&prefix.to_ascii_lowercase());

        prop_assert!(protects(ANY_CHARACTERS, &name));
        let prefixed_glob = format!("{prefix}{ANY_CHARACTERS}");
        prop_assert_eq!(protects(&prefixed_glob, &name), starts_with_prefix);
    }
}
