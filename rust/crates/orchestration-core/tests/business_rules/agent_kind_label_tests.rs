use orchestration_core::agent_kind_label::describe_agent_kind;
use orchestration_core::workflow::AgentKind;
use proptest::prelude::*;

use crate::entity_strategies::agent_kind;

#[test]
fn names_each_agent_kind_as_the_design_shows_it() {
    let names = [
        describe_agent_kind(AgentKind::ClaudeCode),
        describe_agent_kind(AgentKind::Codex),
        describe_agent_kind(AgentKind::GeminiCli),
    ];

    assert_eq!(names, ["Claude Code", "Codex", "Gemini CLI"]);
}

proptest! {
    #[test]
    fn test_describe_agent_kind_property_gives_each_kind_its_own_name(
        first in agent_kind(),
        second in agent_kind(),
    ) {
        let first_name = describe_agent_kind(first);
        let second_name = describe_agent_kind(second);

        prop_assert_eq!(first_name == second_name, first == second);
    }

    #[test]
    fn test_describe_agent_kind_property_is_one_trimmed_line(
        kind in agent_kind(),
    ) {
        let name = describe_agent_kind(kind);

        prop_assert!(!name.is_empty());
        prop_assert_eq!(name.trim(), name);
        prop_assert!(!name.contains('\n'));
    }
}
