use chrono::{DateTime, Utc};

pub(crate) fn encode_canonical_message(
    domain: &str,
    parts: &[&[u8]],
) -> Vec<u8> {
    let mut message = Vec::new();
    append_length_prefixed(&mut message, domain.as_bytes());
    for part in parts {
        append_length_prefixed(&mut message, part);
    }
    message
}

pub(crate) fn encode_timestamp(moment: DateTime<Utc>) -> Vec<u8> {
    let seconds = moment.timestamp().to_be_bytes();
    let nanoseconds = moment.timestamp_subsec_nanos().to_be_bytes();
    [seconds.as_slice(), nanoseconds.as_slice()].concat()
}

fn append_length_prefixed(message: &mut Vec<u8>, part: &[u8]) {
    let part_length = part.len() as u64;
    message.extend_from_slice(&part_length.to_be_bytes());
    message.extend_from_slice(part);
}
