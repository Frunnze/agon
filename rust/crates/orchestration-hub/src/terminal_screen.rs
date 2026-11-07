use unicode_width::UnicodeWidthChar;

use crate::terminal_sequences::{EraseScope, SequenceReader, TerminalAction};

pub const MAXIMUM_KEPT_LINES: usize = 2000;
const TAB_WIDTH: usize = 8;
const BLANK: &str = " ";
const UNKNOWN_CHARACTER_WIDTH: usize = 1;

type ScreenLine = Vec<String>;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct TerminalSize {
    pub columns: u16,
    pub rows: u16,
}

#[derive(Clone, Debug)]
pub struct TerminalScreen {
    lines: Vec<ScreenLine>,
    row: usize,
    column: usize,
    is_wrap_pending: bool,
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
            is_wrap_pending: false,
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
        let mut shown = Vec::new();
        for line in &self.lines {
            shown.push(line.concat().trim_end().to_owned());
        }
        while shown.last().is_some_and(String::is_empty) {
            shown.pop();
        }
        shown
    }

    fn apply(&mut self, action: TerminalAction) {
        let is_printing = matches!(action, TerminalAction::Print(_));
        if !is_printing {
            self.is_wrap_pending = false;
        }
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
            TerminalAction::EraseSavedLines => self.erase_saved_lines(),
        }
    }

    fn print(&mut self, character: char) {
        let given_width = character.width().unwrap_or(UNKNOWN_CHARACTER_WIDTH);
        let width = given_width.min(self.columns);
        if width == 0 {
            self.attach_mark(character);
            return;
        }
        if self.is_wrap_pending || self.column + width > self.columns {
            self.move_to_line_start(self.row + 1);
        }

        let column = self.column;
        let next_column = column + width;
        let line = self.line_under_cursor();
        if line.len() < next_column {
            line.resize(next_column, BLANK.to_owned());
        }
        clear_broken_halves(line, column, next_column);
        line[column] = character.to_string();
        for continuation in &mut line[column + 1..next_column] {
            continuation.clear();
        }

        self.is_wrap_pending = next_column == self.columns;
        self.column = next_column.min(self.last_column());
    }

    fn attach_mark(&mut self, mark: char) {
        let end = self.column + usize::from(self.is_wrap_pending);
        let line = self.line_under_cursor();
        if line.len() < end {
            line.resize(end, BLANK.to_owned());
        }
        let base_cell =
            line[..end].iter_mut().rev().find(|cell| !cell.is_empty());
        if let Some(cell) = base_cell {
            cell.push(mark);
        }
    }

    fn move_to_line_start(&mut self, row: usize) {
        self.row = row;
        self.column = 0;
        self.keep_cursor_line();
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
        let (start, end) = match scope {
            EraseScope::ToEnd => (column, line.len()),
            EraseScope::ToStart => (0, column + 1),
            EraseScope::All => (0, line.len()),
        };
        let end = end.min(line.len());
        let start = start.min(end);
        clear_broken_halves(line, start, end);
        for cell in &mut line[start..end] {
            BLANK.clone_into(cell);
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

    fn erase_saved_lines(&mut self) {
        let saved_line_count = self.find_screen_top();
        let kept_saved_lines = saved_line_count.min(self.lines.len());
        self.lines.drain(..kept_saved_lines);
        self.row -= saved_line_count;
    }

    fn line_under_cursor(&mut self) -> &mut ScreenLine {
        self.keep_cursor_line();
        &mut self.lines[self.row]
    }

    fn keep_cursor_line(&mut self) {
        if self.lines.len() <= self.row {
            self.lines.resize(self.row + 1, Vec::new());
        }
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

fn clear_broken_halves(line: &mut ScreenLine, start: usize, end: usize) {
    let starts_inside_wide_character =
        start > 0 && line.get(start).is_some_and(String::is_empty);
    if starts_inside_wide_character {
        BLANK.clone_into(&mut line[start - 1]);
    }
    if line.get(end).is_some_and(String::is_empty) {
        BLANK.clone_into(&mut line[end]);
    }
}
