use orchestration_hub::command_label::label_shell_command;
use proptest::prelude::*;

const NAMED_COMMANDS: [(&str, &str); 32] = [
    ("npm test", "Run the tests"),
    ("pnpm test", "Run the tests"),
    ("yarn test", "Run the tests"),
    ("npm run test", "Run the tests"),
    ("npm run lint", "Run the lint script"),
    ("npm install", "Install packages with npm"),
    (
        "npm install -D markdownlint-cli2",
        "Install markdownlint-cli2 with npm",
    ),
    ("pnpm add zod vitest", "Install zod, vitest with pnpm"),
    ("yarn add left-pad", "Install left-pad with yarn"),
    ("npm audit", "Run npm audit"),
    ("npx markdownlint-cli2 \"**/*.md\"", "Run markdownlint-cli2"),
    ("cargo test --workspace", "Run the tests"),
    ("cargo build --release", "Build the project"),
    ("cargo doc", "Run cargo doc"),
    ("pytest -q tests", "Run the tests"),
    ("git status", "Check the git status"),
    ("git diff HEAD", "Show the changes"),
    ("git log --oneline", "Read the git history"),
    ("git commit -m \"Fix it\"", "Commit the changes"),
    ("git push origin main", "Push commits"),
    ("git rebase main", "Run git rebase"),
    ("ls -la", "Read files"),
    ("cat README.md", "Read files"),
    ("grep -rn approval src", "Read files"),
    ("sed -n 1,20p main.rs", "Read files"),
    ("mkdir -p build", "Change files"),
    ("cp a.txt b.txt", "Change files"),
    ("mv a.txt b.txt", "Change files"),
    ("rm -rf build", "Delete files"),
    ("/usr/local/bin/terraform plan", "Run terraform"),
    ("./scripts/build.sh --fast", "Run build.sh"),
    ("", "Run a command"),
];

const CHAINED_COMMANDS: [(&str, &str); 5] = [
    ("cd app && npm test", "Run the tests"),
    ("cd app; cargo test", "Run the tests"),
    (
        "C=\"the task folder/app\"; cd \"$C\" && npm test",
        "Run the tests",
    ),
    ("NODE_ENV=test npm test", "Run the tests"),
    ("git commit -m \"first line", "Commit the changes"),
];

#[test]
fn common_programs_are_named_from_the_table() {
    for (command, expected_label) in NAMED_COMMANDS {
        assert_eq!(label_shell_command(command), expected_label, "{command}");
    }
}

#[test]
fn folder_changes_and_settings_are_skipped() {
    for (command, expected_label) in CHAINED_COMMANDS {
        assert_eq!(label_shell_command(command), expected_label, "{command}");
    }
}

#[test]
fn only_the_first_line_names_the_command() {
    let command = "npm test\nrm -rf build";

    assert_eq!(label_shell_command(command), "Run the tests");
}

proptest! {
    #[test]
    fn test_label_shell_command_property_names_unknown_programs(
        program in "[a-z][a-z0-9-]{2,12}",
        arguments in "( [a-z0-9./-]{1,10}){0,4}",
    ) {
        let known_programs = [
            "npm", "pnpm", "yarn", "bun", "npx", "cargo", "pytest", "git",
            "flutter", "go", "ls", "cat", "head", "tail", "grep", "rg",
            "find", "sed", "wc", "mkdir", "touch", "cp", "mv", "rm",
            "rmdir", "cd", "export", "bunx",
        ];
        prop_assume!(!known_programs.contains(&program.as_str()));

        let label = label_shell_command(&format!("{program}{arguments}"));

        prop_assert_eq!(label, format!("Run {program}"));
    }

    #[test]
    fn test_label_shell_command_property_is_one_line(
        command in "\\PC{0,200}(\n\\PC{0,80}){0,3}",
    ) {
        let label = label_shell_command(&command);

        prop_assert!(!label.trim().is_empty());
        prop_assert!(!label.contains('\n'));
    }
}
