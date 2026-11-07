use orchestration_core::identifiers::TaskId;
use uuid::Uuid;

const RUN_NUMBER_MARKER: &str = "-run-";
const NAME_PART_SEPARATOR: char = '-';
const SIMPLE_IDENTIFIER_LENGTH: usize = 32;

#[must_use]
pub fn read_task_id(folder_name: &str) -> Option<TaskId> {
    read_ending_task_id(folder_name)
        .or_else(|| read_ending_task_id(strip_run_number(folder_name)))
}

fn read_ending_task_id(task_part: &str) -> Option<TaskId> {
    let (_readable_part, identifier_text) =
        task_part.rsplit_once(NAME_PART_SEPARATOR)?;
    if !is_simple_identifier(identifier_text) {
        return None;
    }
    let identifier = Uuid::try_parse(identifier_text).ok()?;
    Some(TaskId(identifier))
}

fn strip_run_number(folder_name: &str) -> &str {
    let Some((task_part, run_number)) =
        folder_name.rsplit_once(RUN_NUMBER_MARKER)
    else {
        return folder_name;
    };
    let is_run_number = !run_number.is_empty()
        && run_number.bytes().all(|byte| byte.is_ascii_digit());
    if is_run_number {
        return task_part;
    }
    folder_name
}

fn is_simple_identifier(text: &str) -> bool {
    let is_lower_hexadecimal = text
        .bytes()
        .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte));
    text.len() == SIMPLE_IDENTIFIER_LENGTH && is_lower_hexadecimal
}
