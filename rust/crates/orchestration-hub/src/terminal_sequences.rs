const ESCAPE: char = '\u{1b}';
const BELL: char = '\u{7}';
const BACKSPACE: char = '\u{8}';
const TAB: char = '\t';
const LINE_FEED: char = '\n';
const CARRIAGE_RETURN: char = '\r';
const CONTROL_SEQUENCE_OPENER: char = '[';
const OPERATING_SYSTEM_COMMAND_OPENER: char = ']';
const STRING_TERMINATOR_FINAL: char = '\\';
const PARAMETER_SEPARATOR: char = ';';
const PRIVATE_MARKERS: [char; 4] = ['?', '<', '=', '>'];
const FINAL_BYTES: std::ops::RangeInclusive<char> = '@'..='~';
const LONGEST_KEPT_PARAMETERS: usize = 32;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum EraseScope {
    ToEnd,
    ToStart,
    All,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum TerminalAction {
    Print(char),
    LineFeed,
    CarriageReturn,
    Backspace,
    Tab,
    MoveUp(usize),
    MoveDown(usize),
    MoveForward(usize),
    MoveBack(usize),
    MoveDownToLineStart(usize),
    MoveUpToLineStart(usize),
    MoveToColumn(usize),
    MoveTo { row: usize, column: usize },
    EraseInLine(EraseScope),
    EraseInDisplay(EraseScope),
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
enum ReaderState {
    #[default]
    Text,
    Escape,
    ControlSequence,
    OperatingSystemCommand,
    OperatingSystemEscape,
}

#[derive(Clone, Debug, Default)]
pub(crate) struct SequenceReader {
    state: ReaderState,
    parameters: String,
}

impl SequenceReader {
    pub(crate) fn read(&mut self, character: char) -> Option<TerminalAction> {
        match self.state {
            ReaderState::Text => self.read_text(character),
            ReaderState::Escape => {
                self.read_escape(character);
                None
            }
            ReaderState::ControlSequence => {
                self.read_control_sequence(character)
            }
            ReaderState::OperatingSystemCommand => {
                self.read_operating_system_command(character);
                None
            }
            ReaderState::OperatingSystemEscape => {
                self.state = if character == STRING_TERMINATOR_FINAL {
                    ReaderState::Text
                } else {
                    ReaderState::OperatingSystemCommand
                };
                None
            }
        }
    }

    fn read_text(&mut self, character: char) -> Option<TerminalAction> {
        match character {
            ESCAPE => {
                self.state = ReaderState::Escape;
                None
            }
            LINE_FEED => Some(TerminalAction::LineFeed),
            CARRIAGE_RETURN => Some(TerminalAction::CarriageReturn),
            BACKSPACE => Some(TerminalAction::Backspace),
            TAB => Some(TerminalAction::Tab),
            _ if character.is_control() => None,
            _ => Some(TerminalAction::Print(character)),
        }
    }

    fn read_escape(&mut self, character: char) {
        self.state = match character {
            CONTROL_SEQUENCE_OPENER => {
                self.parameters.clear();
                ReaderState::ControlSequence
            }
            OPERATING_SYSTEM_COMMAND_OPENER => {
                ReaderState::OperatingSystemCommand
            }
            _ => ReaderState::Text,
        };
    }

    fn read_control_sequence(
        &mut self,
        character: char,
    ) -> Option<TerminalAction> {
        if !FINAL_BYTES.contains(&character) {
            if self.parameters.len() < LONGEST_KEPT_PARAMETERS {
                self.parameters.push(character);
            }
            return None;
        }
        self.state = ReaderState::Text;
        describe_control_sequence(&self.parameters, character)
    }

    fn read_operating_system_command(&mut self, character: char) {
        if character == BELL {
            self.state = ReaderState::Text;
        } else if character == ESCAPE {
            self.state = ReaderState::OperatingSystemEscape;
        }
    }
}

fn describe_control_sequence(
    parameters: &str,
    final_character: char,
) -> Option<TerminalAction> {
    if parameters.starts_with(PRIVATE_MARKERS) {
        return None;
    }
    let numbers: Vec<Option<usize>> = parameters
        .split(PARAMETER_SEPARATOR)
        .map(|number| number.parse().ok())
        .collect();
    let count = read_count(&numbers, 0);
    match final_character {
        'A' => Some(TerminalAction::MoveUp(count)),
        'B' => Some(TerminalAction::MoveDown(count)),
        'C' => Some(TerminalAction::MoveForward(count)),
        'D' => Some(TerminalAction::MoveBack(count)),
        'E' => Some(TerminalAction::MoveDownToLineStart(count)),
        'F' => Some(TerminalAction::MoveUpToLineStart(count)),
        'G' => Some(TerminalAction::MoveToColumn(count - 1)),
        'H' | 'f' => Some(TerminalAction::MoveTo {
            row: count - 1,
            column: read_count(&numbers, 1) - 1,
        }),
        'J' => read_scope(&numbers).map(TerminalAction::EraseInDisplay),
        'K' => read_scope(&numbers).map(TerminalAction::EraseInLine),
        _ => None,
    }
}

fn read_count(numbers: &[Option<usize>], position: usize) -> usize {
    let given = numbers.get(position).copied().flatten().unwrap_or(1);
    given.max(1)
}

fn read_scope(numbers: &[Option<usize>]) -> Option<EraseScope> {
    match numbers.first().copied().flatten().unwrap_or(0) {
        0 => Some(EraseScope::ToEnd),
        1 => Some(EraseScope::ToStart),
        2 | 3 => Some(EraseScope::All),
        _ => None,
    }
}
