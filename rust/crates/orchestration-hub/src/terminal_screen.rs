use crate::terminal_sequences::{EraseScope, SequenceReader, TerminalAction};

pub const MAXIMUM_KEPT_LINES: usize = 2000;
const TAB_WIDTH: usize = 8;
const BLANK: char = ' ';

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct TerminalSize {
    pub columns: u16,
    pub rows: u16,
}

#[derive(Clone, Debug)]
pub struct TerminalScreen {
    lines: Vec<Vec<char>>,
    row: usize,
    column: usize,
    columns: usize,
    rows: usize,
    reader: SequenceReader,
}

impl TerminalScreen {
    #[must_use]
    pub fn new(size: TerminalSize) -> Self {
        Self {
            lines: Vec::new(),
            row: 0,
            column: 0,
            columns: usize::from(size.columns).max(1),
            rows: usize::from(size.rows).max(1),
            reader: SequenceReader::default(),
        }
    }

    pub fn feed(&mut self, text: &str) {
        for character in text.chars() {
            if let Some(action) = self.reader.read(character) {
                self.apply(action);
            }
        }
        self.forget_oldest_lines();
    }

    #[must_use]
    pub fn lines(&self) -> Vec<String> {
        let mut shown: Vec<String> = self
            .lines
            .iter()
            .map(|line| {
                let text: String = line.iter().collect();
                text.trim_end().to_owned()
            })
            .collect();
        while shown.last().is_some_and(String::is_empty) {
            shown.pop();
        }
        shown
    }

    fn apply(&mut self, action: TerminalAction) {
        match action {
            TerminalAction::Print(character) => self.print(character),
            TerminalAction::LineFeed => self.move_to_line_start(self.row + 1),
            TerminalAction::CarriageReturn => self.column = 0,
            TerminalAction::Backspace => {
                self.column = self.column.saturating_sub(1);
            }
            TerminalAction::Tab => {
                let next_stop = (self.column / TAB_WIDTH + 1) * TAB_WIDTH;
                self.column = next_stop.min(self.last_column());
            }
            TerminalAction::MoveUp(count) => self.move_up(count),
            TerminalAction::MoveDown(count) => self.move_down(count),
            TerminalAction::MoveForward(count) => {
                let moved = self.column.saturating_add(count);
                self.column = moved.min(self.last_column());
            }
            TerminalAction::MoveBack(count) => {
                self.column = self.column.saturating_sub(count);
            }
            TerminalAction::MoveDownToLineStart(count) => {
                self.move_down(count);
                self.column = 0;
            }
            TerminalAction::MoveUpToLineStart(count) => {
                self.move_up(count);
                self.column = 0;
            }
            TerminalAction::MoveToColumn(column) => {
                self.column = column.min(self.last_column());
            }
            TerminalAction::MoveTo { row, column } => {
                let screen_row = row.min(self.rows - 1);
                self.row = self.find_screen_top() + screen_row;
                self.column = column.min(self.last_column());
            }
            TerminalAction::EraseInLine(scope) => self.erase_in_line(scope),
            TerminalAction::EraseInDisplay(scope) => {
                self.erase_in_display(scope);
            }
        }
    }

    fn print(&mut self, character: char) {
        if self.column >= self.columns {
            self.move_to_line_start(self.row + 1);
        }
        let column = self.column;
        let line = self.line_under_cursor();
        if line.len() <= column {
            line.resize(column + 1, BLANK);
        }
        line[column] = character;
        self.column += 1;
    }

    fn move_to_line_start(&mut self, row: usize) {
        self.row = row;
        self.column = 0;
        self.forget_oldest_lines();
    }

    fn move_up(&mut self, count: usize) {
        let screen_top = self.find_screen_top();
        self.row = self.row.saturating_sub(count).max(screen_top);
    }

    fn move_down(&mut self, count: usize) {
        let screen_bottom = self.find_screen_top() + self.rows - 1;
        self.row = self.row.saturating_add(count).min(screen_bottom);
    }

    fn erase_in_line(&mut self, scope: EraseScope) {
        let column = self.column;
        let line = self.line_under_cursor();
        match scope {
            EraseScope::ToEnd => line.truncate(column),
            EraseScope::ToStart => {
                let erased_end = (column + 1).min(line.len());
                line[..erased_end].fill(BLANK);
            }
            EraseScope::All => line.clear(),
        }
    }

    fn erase_in_display(&mut self, scope: EraseScope) {
        let screen_top = self.find_screen_top();
        self.erase_in_line(scope);
        let row = self.row;
        let erased_rows = match scope {
            EraseScope::ToEnd => row + 1..self.lines.len(),
            EraseScope::ToStart => screen_top..row,
            EraseScope::All => screen_top..self.lines.len(),
        };
        for erased_row in erased_rows {
            if let Some(line) = self.lines.get_mut(erased_row) {
                line.clear();
            }
        }
    }

    fn line_under_cursor(&mut self) -> &mut Vec<char> {
        if self.lines.len() <= self.row {
            self.lines.resize(self.row + 1, Vec::new());
        }
        &mut self.lines[self.row]
    }

    fn find_screen_top(&self) -> usize {
        let used_rows = self.lines.len().max(self.row + 1);
        used_rows.saturating_sub(self.rows)
    }

    fn last_column(&self) -> usize {
        self.columns - 1
    }

    fn forget_oldest_lines(&mut self) {
        let used_rows = self.lines.len().max(self.row + 1);
        let surplus = used_rows.saturating_sub(MAXIMUM_KEPT_LINES);
        if surplus == 0 {
            return;
        }
        let dropped = surplus.min(self.lines.len());
        self.lines.drain(..dropped);
        self.row = self.row.saturating_sub(surplus);
    }
}
