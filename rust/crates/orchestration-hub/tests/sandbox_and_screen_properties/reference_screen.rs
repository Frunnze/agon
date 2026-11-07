use orchestration_hub::terminal_screen::TerminalSize;

use crate::screen_operations::{
    MARK_CHARACTERS, ScreenOperation, WIDE_CHARACTERS,
};

const TAB_WIDTH: usize = 8;
const BLANK: &str = " ";
const WIDE_WIDTH: usize = 2;

type Cells = Vec<String>;

#[derive(Clone, Debug)]
pub struct ReferenceScreen {
    saved_lines: Vec<Cells>,
    screen: Vec<Cells>,
    row: usize,
    column: usize,
    is_wrap_pending: bool,
    columns: usize,
    rows: usize,
}

fn character_width(character: char) -> usize {
    if WIDE_CHARACTERS.contains(&character) {
        return WIDE_WIDTH;
    }
    if MARK_CHARACTERS.contains(&character) {
        return 0;
    }
    1
}

fn blank_line(columns: usize) -> Cells {
    vec![BLANK.to_owned(); columns]
}

fn clear_broken_halves(line: &mut Cells, start: usize, end: usize) {
    if start > 0 && line[start].is_empty() {
        BLANK.clone_into(&mut line[start - 1]);
    }
    if end < line.len() && line[end].is_empty() {
        BLANK.clone_into(&mut line[end]);
    }
}

fn erase_cells(line: &mut Cells, start: usize, end: usize) {
    clear_broken_halves(line, start, end);
    for cell in &mut line[start..end] {
        BLANK.clone_into(cell);
    }
}

fn first_count(count: usize) -> usize {
    count.max(1)
}

impl ReferenceScreen {
    pub fn new(size: TerminalSize) -> Self {
        let columns = usize::from(size.columns).max(1);
        let rows = usize::from(size.rows).max(1);
        Self {
            saved_lines: Vec::new(),
            screen: vec![blank_line(columns); rows],
            row: 0,
            column: 0,
            is_wrap_pending: false,
            columns,
            rows,
        }
    }

    pub fn apply(&mut self, operation: ScreenOperation) {
        match operation {
            ScreenOperation::Print(character) => self.print(character),
            ScreenOperation::Ignored(_) => {}
            moving_or_erasing => {
                self.is_wrap_pending = false;
                self.move_or_erase(moving_or_erasing);
            }
        }
    }

    fn move_or_erase(&mut self, operation: ScreenOperation) {
        let last_row = self.rows - 1;
        let last_column = self.columns - 1;
        match operation {
            ScreenOperation::Print(_) | ScreenOperation::Ignored(_) => {}
            ScreenOperation::LineFeed => self.feed_line(),
            ScreenOperation::CarriageReturn => self.column = 0,
            ScreenOperation::Backspace => {
                self.column = self.column.saturating_sub(1);
            }
            ScreenOperation::Tab => {
                let next_stop = (self.column / TAB_WIDTH + 1) * TAB_WIDTH;
                self.column = next_stop.min(last_column);
            }
            ScreenOperation::Up(count) => self.move_up(count),
            ScreenOperation::Down(count) => self.move_down(count),
            ScreenOperation::Forward(count) => {
                let moved = self.column + first_count(count);
                self.column = moved.min(last_column);
            }
            ScreenOperation::Back(count) => {
                self.column = self.column.saturating_sub(first_count(count));
            }
            ScreenOperation::NextLine(count) => {
                self.move_down(count);
                self.column = 0;
            }
            ScreenOperation::PreviousLine(count) => {
                self.move_up(count);
                self.column = 0;
            }
            ScreenOperation::Column(column) => {
                self.column = (first_count(column) - 1).min(last_column);
            }
            ScreenOperation::Position(row, column) => {
                self.row = (first_count(row) - 1).min(last_row);
                self.column = (first_count(column) - 1).min(last_column);
            }
            ScreenOperation::EraseLine(scope) => self.erase_line(scope),
            ScreenOperation::EraseDisplay(scope) => self.erase_display(scope),
        }
    }

    fn print(&mut self, character: char) {
        let width = character_width(character);
        if width == 0 {
            self.attach_mark(character);
            return;
        }
        if self.is_wrap_pending || self.column + width > self.columns {
            self.feed_line();
        }
        let column = self.column;
        let line = &mut self.screen[self.row];
        clear_broken_halves(line, column, column + width);
        line[column] = character.to_string();
        if width == WIDE_WIDTH {
            line[column + 1] = String::new();
        }
        let next_column = column + width;
        self.is_wrap_pending = next_column == self.columns;
        self.column = next_column.min(self.columns - 1);
    }

    fn attach_mark(&mut self, mark: char) {
        let end = self.column + usize::from(self.is_wrap_pending);
        let line = &mut self.screen[self.row];
        let base_cell =
            line[..end].iter_mut().rev().find(|cell| !cell.is_empty());
        if let Some(cell) = base_cell {
            cell.push(mark);
        }
    }

    fn feed_line(&mut self) {
        self.column = 0;
        if self.row + 1 < self.rows {
            self.row += 1;
            return;
        }
        let scrolled_line = self.screen.remove(0);
        self.saved_lines.push(scrolled_line);
        self.screen.push(blank_line(self.columns));
    }

    fn move_up(&mut self, count: usize) {
        self.row = self.row.saturating_sub(first_count(count));
    }

    fn move_down(&mut self, count: usize) {
        self.row = (self.row + first_count(count)).min(self.rows - 1);
    }

    fn erase_line(&mut self, scope: usize) {
        let (start, end) = match scope {
            0 => (self.column, self.columns),
            1 => (0, self.column + 1),
            _ => (0, self.columns),
        };
        erase_cells(&mut self.screen[self.row], start, end);
    }

    fn erase_display(&mut self, scope: usize) {
        let erased_rows = match scope {
            0 => self.row + 1..self.rows,
            1 => 0..self.row,
            2 => 0..self.rows,
            _ => {
                self.saved_lines.clear();
                return;
            }
        };
        if scope < 2 {
            self.erase_line(scope);
        }
        for erased_row in erased_rows {
            self.screen[erased_row] = blank_line(self.columns);
        }
    }

    pub fn lines(&self) -> Vec<String> {
        let mut shown = Vec::new();
        for line in self.saved_lines.iter().chain(&self.screen) {
            shown.push(line.concat().trim_end().to_owned());
        }
        while shown.last().is_some_and(String::is_empty) {
            shown.pop();
        }
        shown
    }
}
