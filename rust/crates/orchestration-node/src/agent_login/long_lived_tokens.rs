const TOKEN_PREFIX: &str = "sk-ant-oat";
const VERSION_END: char = '-';
const HIDDEN_TOKEN: &str = "sk-ant-••••••••";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct TokenSpan {
    start: usize,
    end: usize,
}

#[must_use]
pub fn find_long_lived_token(text: &str) -> Option<String> {
    let spans = find_token_spans(text);
    let last = spans.last()?;
    Some(text[last.start..last.end].to_owned())
}

#[must_use]
pub fn hide_long_lived_tokens(text: &str) -> String {
    let mut hidden = String::with_capacity(text.len());
    let mut shown_until = 0;
    for span in find_token_spans(text) {
        hidden.push_str(&text[shown_until..span.start]);
        hidden.push_str(HIDDEN_TOKEN);
        shown_until = span.end;
    }
    hidden.push_str(&text[shown_until..]);
    hidden
}

fn find_token_spans(text: &str) -> Vec<TokenSpan> {
    let mut spans = Vec::new();
    let mut search_from = 0;
    while let Some(offset) = text[search_from..].find(TOKEN_PREFIX) {
        let start = search_from + offset;
        let after_prefix = start + TOKEN_PREFIX.len();
        match measure_token(&text[after_prefix..]) {
            Some(length) => {
                let end = after_prefix + length;
                spans.push(TokenSpan { start, end });
                search_from = end;
            }
            None => search_from = after_prefix,
        }
    }
    spans
}

fn measure_token(after_prefix: &str) -> Option<usize> {
    let version_length = after_prefix
        .find(|character: char| !character.is_ascii_digit())
        .unwrap_or(after_prefix.len());
    if version_length == 0 {
        return None;
    }
    let after_version = &after_prefix[version_length..];
    let secret = after_version.strip_prefix(VERSION_END)?;
    let secret_length = secret
        .find(|character: char| !is_token_character(character))
        .unwrap_or(secret.len());
    if secret_length == 0 {
        return None;
    }
    Some(version_length + VERSION_END.len_utf8() + secret_length)
}

fn is_token_character(character: char) -> bool {
    character.is_ascii_alphanumeric() || character == '-' || character == '_'
}
