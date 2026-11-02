#[must_use]
pub fn drain_complete_text(pending: &mut Vec<u8>) -> String {
    let complete_length = match std::str::from_utf8(pending) {
        Err(problem) if problem.error_len().is_none() => problem.valid_up_to(),
        Ok(_) | Err(_) => pending.len(),
    };
    let complete_bytes: Vec<u8> = pending.drain(..complete_length).collect();
    String::from_utf8_lossy(&complete_bytes).into_owned()
}
