use chrono::DateTime;
use orchestration_api::work::FollowUp;
use orchestration_core::run::{ChatAuthor, ChatMessage};
use orchestration_runner::step_opening::{
    StepOpening, choose_step_opening, count_answered_messages,
};
use proptest::prelude::*;

use crate::assignments::claude_assignment;
use crate::executor_support::RUN_NUMBER;
use crate::support::to_case_error;

const STEP_TITLE: &str = "fix-it";

fn chat_author_strategy() -> impl Strategy<Value = ChatAuthor> {
    prop_oneof![
        Just(ChatAuthor::You),
        Just(ChatAuthor::Agent),
        Just(ChatAuthor::Tool),
    ]
}

fn chat_message_by(author: ChatAuthor) -> ChatMessage {
    ChatMessage {
        at: DateTime::UNIX_EPOCH,
        author,
        text: "message".to_string(),
        is_error: false,
        waiting_to_send: false,
    }
}

fn follow_up_with(answered: Option<usize>) -> Option<FollowUp> {
    answered.map(|answered_user_messages| FollowUp {
        answered_user_messages,
    })
}

proptest! {
    #[test]
    fn test_choose_step_opening_property_resumes_only_a_kept_follow_up(
        session in proptest::option::of("[a-z0-9-]{1,12}"),
        answered in proptest::option::of(0_usize..5),
        fresh_prompt in "[a-z ]{0,20}",
    ) {
        let mut assignment = claude_assignment(RUN_NUMBER, STEP_TITLE)
            .map_err(to_case_error)?;
        assignment.run.agent_session.clone_from(&session);
        assignment.follow_up = follow_up_with(answered);

        let opening = choose_step_opening(&assignment, fresh_prompt.clone());

        let expected = match (answered, session) {
            (Some(_), Some(session)) => StepOpening::ResumedSession(session),
            _ => StepOpening::FreshPrompt(fresh_prompt),
        };
        prop_assert_eq!(opening, expected);
    }

    #[test]
    fn test_count_answered_messages_property_a_follow_up_sets_the_count(
        authors in proptest::collection::vec(chat_author_strategy(), 0..8),
        answered in proptest::option::of(0_usize..5),
    ) {
        let mut assignment = claude_assignment(RUN_NUMBER, STEP_TITLE)
            .map_err(to_case_error)?;
        let mut chat = Vec::new();
        for author in &authors {
            chat.push(chat_message_by(*author));
        }
        assignment.run.chat = chat;
        assignment.follow_up = follow_up_with(answered);

        let counted = count_answered_messages(&assignment);

        let person_messages = authors
            .iter()
            .filter(|author| **author == ChatAuthor::You)
            .count();
        prop_assert_eq!(counted, answered.unwrap_or(person_messages));
    }
}
