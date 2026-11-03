use serde_json::Value;

pub fn join_words(text: &str) -> String {
    let words: Vec<&str> = text.split_whitespace().collect();
    words.join(" ")
}

pub fn reads_as_json(text: &str) -> bool {
    serde_json::from_str::<Value>(&join_words(text))
        .is_ok_and(|value| value.is_object() || value.is_array())
}
