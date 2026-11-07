#[must_use]
pub fn drain_complete_text(pending: &mut Vec<u8>) -> String {
    let complete_length = measure_complete_bytes(pending);
    let complete_bytes: Vec<u8> = pending.drain(..complete_length).collect();
    String::from_utf8_lossy(&complete_bytes).into_owned()
}

fn measure_complete_bytes(bytes: &[u8]) -> usize {
    let mut checked_length = 0;
    loop {
        let unchecked_bytes = &bytes[checked_length..];
        let Err(problem) = std::str::from_utf8(unchecked_bytes) else {
            return bytes.len();
        };
        let Some(invalid_length) = problem.error_len() else {
            return checked_length + problem.valid_up_to();
        };
        checked_length += problem.valid_up_to() + invalid_length;
    }
}
