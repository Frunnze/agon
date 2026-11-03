pub(crate) const UNKNOWN_TOOL_FAILURE: &str = "the tool failed";
pub(crate) const UNKNOWN_AGENT_ERROR: &str = "the agent reported an error";
pub(crate) const UNKNOWN_FAILURE_REASON: &str =
    "the agent stopped with an error";

pub(crate) fn choose_given_text(
    given_texts: &[&str],
    fallback: &str,
) -> String {
    for given_text in given_texts {
        let text = given_text.trim();
        if !text.is_empty() {
            return text.to_string();
        }
    }
    fallback.to_string()
}
