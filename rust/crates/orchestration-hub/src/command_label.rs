use std::path::Path;

const UNNAMED_COMMAND_LABEL: &str = "Run a command";
const RUN_THE_TESTS: &str = "Run the tests";
const READ_FILES: &str = "Read files";
const CHANGE_FILES: &str = "Change files";
const DELETE_FILES: &str = "Delete files";
const SEGMENT_SEPARATORS: [&str; 4] = ["&&", "||", ";", "|"];
const TRAILING_SEPARATOR: char = ';';
const ASSIGNMENT_SIGN: char = '=';
const IDENTIFIER_JOINER: char = '_';
const FLAG_PREFIX: char = '-';
const SKIPPED_PROGRAMS: [&str; 2] = ["cd", "export"];
const PACKAGE_MANAGERS: [&str; 4] = ["npm", "pnpm", "yarn", "bun"];
const PACKAGE_RUNNERS: [&str; 2] = ["npx", "bunx"];
const INSTALL_SUBCOMMANDS: [&str; 4] = ["install", "i", "add", "ci"];
const TEST_SUBCOMMANDS: [&str; 2] = ["test", "t"];
const SCRIPT_SUBCOMMAND: &str = "run";
const TEST_SCRIPT: &str = "test";
const PACKAGE_SEPARATOR: &str = ", ";

const PROGRAM_LABELS: [(&str, &str); 16] = [
    ("pytest", RUN_THE_TESTS),
    ("ls", READ_FILES),
    ("cat", READ_FILES),
    ("head", READ_FILES),
    ("tail", READ_FILES),
    ("grep", READ_FILES),
    ("rg", READ_FILES),
    ("find", READ_FILES),
    ("sed", READ_FILES),
    ("wc", READ_FILES),
    ("mkdir", CHANGE_FILES),
    ("touch", CHANGE_FILES),
    ("cp", CHANGE_FILES),
    ("mv", CHANGE_FILES),
    ("rm", DELETE_FILES),
    ("rmdir", DELETE_FILES),
];

const SUBCOMMAND_LABELS: [(&str, &str, &str); 13] = [
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

#[must_use]
pub fn label_shell_command(command: &str) -> String {
    let first_line = command.trim().lines().next().unwrap_or_default();
    let words = split_shell_words(first_line);
    let Some(program_words) = find_main_program(&words) else {
        return UNNAMED_COMMAND_LABEL.to_owned();
    };

    let program = name_program(&program_words[0]);
    let mut arguments: Vec<&str> = Vec::new();
    for word in &program_words[1..] {
        if !word.starts_with(FLAG_PREFIX) {
            arguments.push(word);
        }
    }
    label_program(program, &arguments)
}

fn split_shell_words(line: &str) -> Vec<String> {
    let quoted_words = match shell_words::split(line) {
        Ok(words) => words,
        Err(_unbalanced_quotes) => {
            line.split_whitespace().map(str::to_owned).collect()
        }
    };

    let mut words = Vec::new();
    for word in quoted_words {
        match word.strip_suffix(TRAILING_SEPARATOR) {
            Some(leading_word) if !leading_word.is_empty() => {
                words.push(leading_word.to_owned());
                words.push(TRAILING_SEPARATOR.to_string());
            }
            _ => words.push(word),
        }
    }
    words
}

fn find_main_program(words: &[String]) -> Option<&[String]> {
    let is_separator =
        |word: &String| SEGMENT_SEPARATORS.contains(&word.as_str());
    for segment in words.split(is_separator) {
        let program_position = segment
            .iter()
            .position(|word| !is_variable_assignment(word));
        let Some(program_position) = program_position else {
            continue;
        };

        let program_words = &segment[program_position..];
        if !SKIPPED_PROGRAMS.contains(&program_words[0].as_str()) {
            return Some(program_words);
        }
    }
    None
}

fn is_variable_assignment(word: &str) -> bool {
    let Some((name, _value)) = word.split_once(ASSIGNMENT_SIGN) else {
        return false;
    };
    let starts_with_digit =
        name.starts_with(|character: char| character.is_ascii_digit());
    let is_identifier = name.chars().all(is_identifier_character);
    !name.is_empty() && !starts_with_digit && is_identifier
}

fn is_identifier_character(character: char) -> bool {
    character.is_ascii_alphanumeric() || character == IDENTIFIER_JOINER
}

fn name_program(program_path: &str) -> &str {
    Path::new(program_path)
        .file_name()
        .and_then(|file_name| file_name.to_str())
        .unwrap_or(program_path)
}

fn label_program(program: &str, arguments: &[&str]) -> String {
    if let Some((_, label)) = PROGRAM_LABELS
        .iter()
        .find(|(known_program, _)| *known_program == program)
    {
        return (*label).to_owned();
    }
    if PACKAGE_MANAGERS.contains(&program) {
        return label_package_command(program, arguments);
    }
    if PACKAGE_RUNNERS.contains(&program)
        && let Some(package) = arguments.first()
    {
        return format!("Run {package}");
    }
    label_subcommand(program, arguments)
}

fn label_package_command(manager: &str, arguments: &[&str]) -> String {
    let Some(subcommand) = arguments.first() else {
        return format!("Run {manager}");
    };

    if INSTALL_SUBCOMMANDS.contains(subcommand) {
        let packages = &arguments[1..];
        if packages.is_empty() {
            return format!("Install packages with {manager}");
        }
        let package_list = packages.join(PACKAGE_SEPARATOR);
        return format!("Install {package_list} with {manager}");
    }
    if TEST_SUBCOMMANDS.contains(subcommand) {
        return RUN_THE_TESTS.to_owned();
    }
    if *subcommand == SCRIPT_SUBCOMMAND
        && let Some(script) = arguments.get(1)
    {
        if *script == TEST_SCRIPT {
            return RUN_THE_TESTS.to_owned();
        }
        return format!("Run the {script} script");
    }
    format!("Run {manager} {subcommand}")
}

fn label_subcommand(program: &str, arguments: &[&str]) -> String {
    let takes_subcommands = SUBCOMMAND_LABELS
        .iter()
        .any(|(known_program, _, _)| *known_program == program);
    let Some(subcommand) = arguments.first().filter(|_| takes_subcommands)
    else {
        return format!("Run {program}");
    };

    let known_label = SUBCOMMAND_LABELS.iter().find(
        |(known_program, known_subcommand, _)| {
            *known_program == program && known_subcommand == subcommand
        },
    );
    match known_label {
        Some((_, _, label)) => (*label).to_owned(),
        None => format!("Run {program} {subcommand}"),
    }
}
