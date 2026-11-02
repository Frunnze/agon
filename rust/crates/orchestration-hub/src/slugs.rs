pub const MAXIMUM_SLUG_LENGTH: usize = 40;

const SLUG_SEPARATOR: char = '-';

#[must_use]
pub fn slugify(text: &str) -> String {
    let mut slug = String::new();
    for character in text.chars() {
        if slug.len() >= MAXIMUM_SLUG_LENGTH {
            break;
        }

        if character.is_ascii_alphanumeric() {
            slug.push(character.to_ascii_lowercase());
        } else if !slug.is_empty() && !slug.ends_with(SLUG_SEPARATOR) {
            slug.push(SLUG_SEPARATOR);
        }
    }
    slug.trim_end_matches(SLUG_SEPARATOR).to_string()
}
