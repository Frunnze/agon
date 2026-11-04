use chrono::DateTime;
use orchestration_core::run::{ChatAuthor, ChatMessage};
use orchestration_runner::user_message_watch::collect_new_user_messages;
use proptest::collection::vec;
use proptest::prelude::*;

const BLANK_PATTERN: &str = "[ \t\n]{0,4}";

fn user_message(text: &str) -> ChatMessage {
    ChatMessage {
        at: DateTime::UNIX_EPOCH,
        author: ChatAuthor::You,
        text: text.to_string(),
        is_error: false,
        waiting_to_send: false,
    }
}

fn any_new_text() -> impl Strategy<Value = Option<u8>> {
    prop_oneof![Just(None), any::<u8>().prop_map(Some)]
}

fn name_new_text(number: u8) -> String {
    format!("new-{number:03}")
}

fn build_chat(
    answered_count: usize,
    new_texts: &[Option<u8>],
    blank: &str,
) -> Vec<ChatMessage> {
    let mut chat = Vec::new();
    for answered_number in 0..answered_count {
        chat.push(user_message(&format!("old-{answered_number}")));
    }
    for new_text in new_texts {
        let text = new_text.map_or_else(|| blank.to_string(), name_new_text);
        chat.push(user_message(&text));
    }
    chat
}

proptest! {
    #[test]
    fn test_collect_new_user_messages_property_keeps_new_texts_in_order(
        answered_count in 0usize..4,
        new_texts in vec(any_new_text(), 0..5),
        blank in BLANK_PATTERN,
    ) {
        let chat = build_chat(answered_count, &new_texts, &blank);

        let collected = collect_new_user_messages(&chat, answered_count);

        let spoken: Vec<String> =
            new_texts.iter().flatten().map(|number| name_new_text(*number))
                .collect();
        let Some(new_messages) = collected else {
            prop_assert!(spoken.is_empty());
            return Ok(());
        };
        prop_assert!(!new_messages.prompt.contains("old-"));
        let mut searched_from = 0;
        for text in &spoken {
            let found = new_messages.prompt[searched_from..].find(text);
            prop_assert!(found.is_some(), "{text} is missing in order");
            searched_from += found.unwrap_or_default() + text.len();
        }
    }

    #[test]
    fn test_collect_new_user_messages_property_never_hands_over_twice(
        answered_count in 0usize..4,
        new_texts in vec(any_new_text(), 0..5),
        blank in BLANK_PATTERN,
    ) {
        let chat = build_chat(answered_count, &new_texts, &blank);

        let collected = collect_new_user_messages(&chat, answered_count);

        let Some(new_messages) = collected else {
            return Ok(());
        };
        prop_assert_eq!(new_messages.answered_messages, chat.len());
        let again =
            collect_new_user_messages(&chat, new_messages.answered_messages);
        prop_assert_eq!(again, None);
    }

    #[test]
    fn test_collect_new_user_messages_property_blank_messages_wait(
        answered_count in 0usize..4,
        blank_count in 0usize..4,
        blank in BLANK_PATTERN,
    ) {
        let new_texts = vec![None; blank_count];
        let chat = build_chat(answered_count, &new_texts, &blank);

        let collected = collect_new_user_messages(&chat, answered_count);

        prop_assert_eq!(collected, None);
    }
}
