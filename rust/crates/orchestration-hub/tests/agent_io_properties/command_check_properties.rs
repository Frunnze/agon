use orchestration_core::device::SandboxKind;
use orchestration_hub::agent_command::{
    AgentCommandError, build_agent_command, build_claude_control_command,
};
use proptest::prelude::*;

use crate::command_support::{
    ALL_AGENTS, any_agent, any_blank_prompt, any_prompt, any_sandbox,
    any_valid_session,
};

const EMPTY_PROMPT_MESSAGE: &str = "the prompt is empty";
const SESSION_SEPARATOR: char = '-';
const LOOK_ALIKE_CHARACTERS: [char; 8] =
    ['é', 'ж', 'ß', '١', '٣', 'Ⅷ', '０', '\u{2010}'];

type CheckOutcome = Result<(), AgentCommandError>;

fn check_every_builder(
    prompt: &str,
    session: Option<&str>,
    sandbox: SandboxKind,
) -> Vec<CheckOutcome> {
    let mut outcomes = Vec::new();
    for agent in ALL_AGENTS {
        let command = build_agent_command(agent, prompt, session, sandbox);
        outcomes.push(command.map(|_| ()));
    }
    let control_command = build_claude_control_command(prompt, session);
    outcomes.push(control_command.map(|_| ()));
    outcomes
}

fn is_documented_session(session: &str) -> bool {
    let has_session_characters = session.chars().all(|character| {
        character.is_ascii_alphanumeric() || character == SESSION_SEPARATOR
    });
    let starts_with_letter_or_digit = session
        .chars()
        .next()
        .is_some_and(|character| character != SESSION_SEPARATOR);
    has_session_characters && starts_with_letter_or_digit
}

fn any_session_text() -> impl Strategy<Value = String> {
    prop_oneof![
        any::<String>(),
        "[a-zA-Z0-9-]{0,12}",
        "[a-z0-9-]{0,5}[ \n/=.:_][a-z0-9-]{0,5}",
    ]
}

fn session_with_look_alike() -> impl Strategy<Value = String> {
    let look_alike = proptest::sample::select(LOOK_ALIKE_CHARACTERS.to_vec());
    ("[a-z0-9]{0,6}", look_alike, "[a-z0-9]{0,6}")
        .prop_map(|(start, character, end)| format!("{start}{character}{end}"))
}

proptest! {
    #[test]
    fn test_ensure_prompt_has_text_property_unicode_blanks_are_rejected(
        prompt in any_blank_prompt(),
        sandbox in any_sandbox(),
    ) {
        let outcomes = check_every_builder(&prompt, None, sandbox);

        for outcome in outcomes {
            prop_assert_eq!(outcome, Err(AgentCommandError::EmptyPrompt));
        }
    }

    #[test]
    fn test_ensure_prompt_has_text_property_one_visible_character_is_enough(
        before in any_blank_prompt(),
        visible in "[a-zé中😀?.]",
        after in any_blank_prompt(),
        sandbox in any_sandbox(),
    ) {
        let prompt = format!("{before}{visible}{after}");

        let outcomes = check_every_builder(&prompt, None, sandbox);

        for outcome in outcomes {
            prop_assert_eq!(outcome, Ok(()));
        }
    }

    #[test]
    fn test_ensure_prompt_has_text_property_every_builder_agrees(
        prompt in any::<String>(),
        sandbox in any_sandbox(),
    ) {
        let outcomes = check_every_builder(&prompt, None, sandbox);

        let expected = if prompt.trim().is_empty() {
            Err(AgentCommandError::EmptyPrompt)
        } else {
            Ok(())
        };
        for outcome in outcomes {
            prop_assert_eq!(outcome, expected.clone());
        }
    }

    #[test]
    fn test_check_session_property_rejection_carries_the_session(
        prompt in any_prompt(),
        session in any_session_text(),
        sandbox in any_sandbox(),
    ) {
        prop_assume!(!is_documented_session(&session));

        let outcomes = check_every_builder(&prompt, Some(&session), sandbox);

        let expected = AgentCommandError::InvalidSession(session.clone());
        for outcome in outcomes {
            prop_assert_eq!(outcome, Err(expected.clone()));
        }
    }

    #[test]
    fn test_check_session_property_valid_sessions_are_accepted(
        prompt in any_prompt(),
        session in any_valid_session(),
        sandbox in any_sandbox(),
    ) {
        let outcomes = check_every_builder(&prompt, Some(&session), sandbox);

        for outcome in outcomes {
            prop_assert_eq!(outcome, Ok(()));
        }
    }

    #[test]
    fn test_check_session_property_every_builder_agrees(
        prompt in any_prompt(),
        session in any_session_text(),
        sandbox in any_sandbox(),
    ) {
        let outcomes = check_every_builder(&prompt, Some(&session), sandbox);

        let first_outcome = outcomes[0].clone();
        for outcome in outcomes {
            prop_assert_eq!(outcome, first_outcome.clone());
        }
    }

    #[test]
    fn test_is_valid_session_property_matches_the_documented_alphabet(
        agent in any_agent(),
        prompt in any_prompt(),
        session in any_session_text(),
    ) {
        let command = build_agent_command(
            agent,
            &prompt,
            Some(&session),
            SandboxKind::LocalProcess,
        );

        prop_assert_eq!(command.is_ok(), is_documented_session(&session));
    }

    #[test]
    fn test_is_valid_session_property_look_alike_characters_are_refused(
        agent in any_agent(),
        prompt in any_prompt(),
        session in session_with_look_alike(),
    ) {
        let command = build_agent_command(
            agent,
            &prompt,
            Some(&session),
            SandboxKind::Container,
        );

        let expected = AgentCommandError::InvalidSession(session);
        prop_assert_eq!(command, Err(expected));
    }

    #[test]
    fn test_is_valid_session_property_only_a_leading_dash_is_refused(
        agent in any_agent(),
        prompt in any_prompt(),
        start in "[a-zA-Z0-9]{1,6}",
        end in "[a-zA-Z0-9-]{0,6}",
    ) {
        let inner_dashes = format!("{start}--{end}-");
        let leading_dash = format!("-{start}");

        let accepted = build_agent_command(
            agent,
            &prompt,
            Some(&inner_dashes),
            SandboxKind::LocalProcess,
        );
        let refused = build_agent_command(
            agent,
            &prompt,
            Some(&leading_dash),
            SandboxKind::LocalProcess,
        );

        prop_assert!(accepted.is_ok());
        prop_assert_eq!(
            refused,
            Err(AgentCommandError::InvalidSession(leading_dash))
        );
    }

    #[test]
    fn test_agent_command_error_fmt_property_empty_prompt_says_so(
        agent in any_agent(),
        prompt in any_blank_prompt(),
        sandbox in any_sandbox(),
    ) {
        let command = build_agent_command(agent, &prompt, None, sandbox);

        let message = command.err().map(|problem| problem.to_string());
        prop_assert_eq!(message.as_deref(), Some(EMPTY_PROMPT_MESSAGE));
    }

    #[test]
    fn test_agent_command_error_fmt_property_invalid_session_is_quoted(
        session in any_session_text(),
    ) {
        prop_assume!(!is_documented_session(&session));

        let problem = AgentCommandError::InvalidSession(session.clone());

        let message = problem.to_string();
        let quoted_session = format!("{session:?}");
        prop_assert!(message.contains(&quoted_session), "{}", message);
    }

    #[test]
    fn test_agent_command_error_fmt_property_message_is_one_line(
        session in any_session_text(),
    ) {
        let problem = AgentCommandError::InvalidSession(session);

        let message = problem.to_string();

        prop_assert!(!message.contains(['\n', '\r']), "{}", message);
    }
}
