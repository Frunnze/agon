use proptest::prelude::*;

pub const RUN_THE_TESTS: &str = "Run the tests";
pub const UNNAMED_COMMAND_LABEL: &str = "Run a command";
pub const PACKAGE_MANAGERS: [&str; 4] = ["npm", "pnpm", "yarn", "bun"];
pub const PACKAGE_RUNNERS: [&str; 2] = ["npx", "bunx"];
pub const SUBCOMMAND_PROGRAMS: [&str; 4] = ["cargo", "flutter", "go", "git"];
pub const SEPARATORS: [&str; 4] = ["&&", "||", ";", "|"];

pub const PROGRAM_LABELS: [(&str, &str); 16] = [
    ("pytest", RUN_THE_TESTS),
    ("ls", "Read files"),
    ("cat", "Read files"),
    ("head", "Read files"),
    ("tail", "Read files"),
    ("grep", "Read files"),
    ("rg", "Read files"),
    ("find", "Read files"),
    ("sed", "Read files"),
    ("wc", "Read files"),
    ("mkdir", "Change files"),
    ("touch", "Change files"),
    ("cp", "Change files"),
    ("mv", "Change files"),
    ("rm", "Delete files"),
    ("rmdir", "Delete files"),
];

pub const SUBCOMMAND_LABELS: [(&str, &str, &str); 13] = [
    ("cargo", "test", RUN_THE_TESTS),
    ("cargo", "build", "Build the project"),
    ("cargo", "clippy", "Check the code"),
    ("cargo", "fmt", "Format the code"),
    ("flutter", "test", RUN_THE_TESTS),
    ("go", "test", RUN_THE_TESTS),
    ("git", "status", "Check the git status"),
    ("git", "diff", "Show the changes"),
    ("git", "log", "Read the git history"),
    ("git", "add", "Stage the changes"),
    ("git", "commit", "Commit the changes"),
    ("git", "push", "Push commits"),
    ("git", "pull", "Pull changes"),
];

pub fn any_word() -> impl Strategy<Value = String> {
    "[a-z0-9][a-z0-9._/]{0,10}"
}

pub fn any_words() -> impl Strategy<Value = Vec<String>> {
    proptest::collection::vec(any_word(), 0..4)
}

pub fn any_separator() -> impl Strategy<Value = &'static str> {
    proptest::sample::select(SEPARATORS.to_vec())
}

pub fn any_skipped_prefix() -> impl Strategy<Value = String> {
    prop_oneof![
        any_word().prop_map(|folder| format!("cd {folder}")),
        "[A-Z_]{1,6}=[a-z0-9]{0,4}"
            .prop_map(|assignment| format!("export {assignment}")),
    ]
}

pub fn any_unknown_program() -> impl Strategy<Value = String> {
    "[a-z][a-z0-9]{2,10}".prop_filter("the program is unknown", |program| {
        !is_known_program(program)
    })
}

pub fn any_named_command() -> impl Strategy<Value = (String, String)> {
    let table_command = proptest::sample::select(PROGRAM_LABELS.to_vec())
        .prop_map(|(program, label)| (program.to_owned(), label.to_owned()));
    let subcommand = proptest::sample::select(SUBCOMMAND_LABELS.to_vec())
        .prop_map(|(program, subcommand, label)| {
            (format!("{program} {subcommand}"), label.to_owned())
        });
    prop_oneof![table_command, subcommand]
}

pub fn is_known_program(program: &str) -> bool {
    let is_table_program = PROGRAM_LABELS
        .iter()
        .any(|(known_program, _label)| *known_program == program);
    let is_other_program = PACKAGE_MANAGERS.contains(&program)
        || PACKAGE_RUNNERS.contains(&program)
        || SUBCOMMAND_PROGRAMS.contains(&program);
    is_table_program
        || is_other_program
        || program == "cd"
        || program == "export"
}

pub fn join_command(program: &str, arguments: &[String]) -> String {
    let mut words = vec![program.to_owned()];
    words.extend(arguments.iter().cloned());
    words.join(" ")
}
