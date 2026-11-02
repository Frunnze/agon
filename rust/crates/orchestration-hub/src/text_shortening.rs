const SHORTENED_MARKER: char = '…';

pub(crate) fn shorten_to_characters(
    text: &str,
    maximum_characters: usize,
) -> String {
    if text.chars().count() <= maximum_characters {
        return text.to_string();
    }

    let kept: String = text.chars().take(maximum_characters).collect();
    format!("{}{SHORTENED_MARKER}", kept.trim_end())
}
