use crate::terminal_sequences::{SequenceReader, TerminalAction};

#[must_use]
pub(crate) fn strip_terminal_control_sequences(line: &str) -> String {
    let mut reader = SequenceReader::default();
    let mut kept = String::with_capacity(line.len());

    for character in line.chars() {
        let action = reader.read(character);
        let is_text = matches!(
            action,
            Some(
                TerminalAction::Print(_)
                    | TerminalAction::LineFeed
                    | TerminalAction::CarriageReturn
                    | TerminalAction::Backspace
                    | TerminalAction::Tab
            )
        );
        if is_text {
            kept.push(character);
        }
    }

    kept
}
