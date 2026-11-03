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

pub(crate) fn shorten_keeping_the_end(
    text: &str,
    maximum_characters: usize,
) -> String {
    let character_count = text.chars().count();
    if character_count <= maximum_characters {
        return text.to_string();
    }

    let skipped_characters = character_count - maximum_characters;
    let kept: String = text.chars().skip(skipped_characters).collect();
    format!("{SHORTENED_MARKER}{}", kept.trim_start())
}
