use std::collections::BTreeMap;
use std::error::Error;
use std::time::{Duration, Instant};

use orchestration_hub::command_specification::CommandSpecification;
use orchestration_hub::interactive_terminal::{
    InteractiveTerminal, start_interactive_terminal,
};
use orchestration_hub::process_supervisor::{ProcessExit, SupervisorError};
use orchestration_hub::terminal_screen::{TerminalScreen, TerminalSize};
use orchestration_hub::utf8_chunks::drain_complete_text;
use proptest::prelude::*;

type TestResult = Result<(), Box<dyn Error>>;

const SHELL: &str = "/bin/sh";
const OUTPUT_LIMIT: Duration = Duration::from_secs(10);
const POLL_PAUSE: Duration = Duration::from_millis(20);
const TERMINAL_SIZE: TerminalSize = TerminalSize {
    columns: 512,
    rows: 40,
};
const TERMINAL_CASES: u32 = 12;
const LONGEST_UTF8_SEQUENCE: usize = 4;

fn shell_command(script: &str, arguments: &[String]) -> CommandSpecification {
    let mut shell_arguments =
        vec!["-c".to_owned(), script.to_owned(), "sh".to_owned()];
    shell_arguments.extend(arguments.iter().cloned());
    CommandSpecification {
        program: SHELL.to_owned(),
        arguments: shell_arguments,
        environment: BTreeMap::new(),
        working_directory: None,
    }
}

fn read_until(
    terminal: &mut InteractiveTerminal,
    screen: &mut TerminalScreen,
    expected: &str,
) -> Result<(), String> {
    let deadline = Instant::now() + OUTPUT_LIMIT;
    loop {
        while let Ok(text) = terminal.output.try_recv() {
            screen.feed(&text);
        }
        if screen.lines().join("\n").contains(expected) {
            return Ok(());
        }
        if Instant::now() >= deadline {
            return Err(format!("{expected:?} never appeared"));
        }
        std::thread::sleep(POLL_PAUSE);
    }
}

fn read_to_end(terminal: &mut InteractiveTerminal) -> String {
    let mut output = String::new();
    while let Some(text) = terminal.output.blocking_recv() {
        output.push_str(&text);
    }
    output
}

fn split_into_chunks(bytes: &[u8], cut_points: &[usize]) -> Vec<Vec<u8>> {
    let mut cuts: Vec<usize> = cut_points
        .iter()
        .map(|point| point % (bytes.len() + 1))
        .collect();
    cuts.sort_unstable();
    let mut chunks = Vec::new();
    let mut start = 0;
    for cut in cuts {
        chunks.push(bytes[start..cut].to_vec());
        start = cut;
    }
    chunks.push(bytes[start..].to_vec());
    chunks
}

#[test]
fn typed_keys_reach_the_program_like_in_a_terminal() -> TestResult {
    let script =
        "printf 'code? '; read answer; printf 'got %s\\n' \"$answer\"";
    let mut terminal = start_interactive_terminal(
        &shell_command(script, &[]),
        TERMINAL_SIZE,
    )?;
    let mut screen = TerminalScreen::new(TERMINAL_SIZE);

    read_until(&mut terminal, &mut screen, "code?")?;
    terminal.keyboard.send_keys("abc123\r")?;
    screen.feed(&read_to_end(&mut terminal));
    let exit = terminal.process.wait_for_exit()?;

    assert!(screen.lines().contains(&"got abc123".to_owned()));
    assert_eq!(exit, ProcessExit::Succeeded);
    Ok(())
}

#[test]
fn stopping_ends_a_program_that_waits() -> TestResult {
    let mut terminal = start_interactive_terminal(
        &shell_command("sleep 30", &[]),
        TERMINAL_SIZE,
    )?;

    terminal.stopper.stop()?;
    let _output = read_to_end(&mut terminal);
    let exit = terminal.process.wait_for_exit()?;

    assert!(matches!(exit, ProcessExit::KilledBySignal(_)), "{exit:?}");
    Ok(())
}

#[test]
fn the_exit_code_is_reported() -> TestResult {
    let mut terminal = start_interactive_terminal(
        &shell_command("exit 3", &[]),
        TERMINAL_SIZE,
    )?;

    let _output = read_to_end(&mut terminal);
    let exit = terminal.process.wait_for_exit()?;

    assert_eq!(exit, ProcessExit::FailedWithCode(3));
    Ok(())
}

#[test]
fn the_program_sees_the_requested_terminal_size() -> TestResult {
    let mut terminal = start_interactive_terminal(
        &shell_command("stty size", &[]),
        TERMINAL_SIZE,
    )?;

    let output = read_to_end(&mut terminal);

    assert!(output.contains("40 512"), "{output:?}");
    Ok(())
}

#[test]
fn a_missing_program_cannot_start() {
    let command = CommandSpecification {
        program: "/nonexistent/orchestration-login".to_owned(),
        arguments: Vec::new(),
        environment: BTreeMap::new(),
        working_directory: None,
    };

    let started = start_interactive_terminal(&command, TERMINAL_SIZE);

    assert!(matches!(started, Err(SupervisorError::StartProcess { .. })));
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(TERMINAL_CASES))]

    #[test]
    fn test_start_interactive_terminal_property_printed_text_arrives_whole(
        text in "[ -~é✓]{1,200}",
    ) {
        let command = shell_command("printf '%s' \"$1\"", &[text.clone()]);
        let started = start_interactive_terminal(&command, TERMINAL_SIZE);
        let Ok(mut terminal) = started else {
            return Err(TestCaseError::fail(format!("{started:?}")));
        };

        let output = read_to_end(&mut terminal);

        prop_assert_eq!(output, text);
    }
}

proptest! {
    #[test]
    fn test_drain_complete_text_property_chunked_text_joins_back(
        text in "\\PC{0,80}",
        cut_points in proptest::collection::vec(any::<usize>(), 0..6),
    ) {
        let mut pending = Vec::new();
        let mut joined = String::new();

        for chunk in split_into_chunks(text.as_bytes(), &cut_points) {
            pending.extend_from_slice(&chunk);
            joined.push_str(&drain_complete_text(&mut pending));
        }

        prop_assert_eq!(joined, text);
        prop_assert!(pending.is_empty());
    }

    #[test]
    fn test_drain_complete_text_property_arbitrary_bytes_leave_little_behind(
        bytes in proptest::collection::vec(any::<u8>(), 0..80),
    ) {
        let mut pending = bytes;

        let _text = drain_complete_text(&mut pending);

        prop_assert!(pending.len() < LONGEST_UTF8_SEQUENCE);
    }
}
