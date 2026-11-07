use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::SandboxKind;
use orchestration_core::workflow::AgentKind;
use orchestration_hub::agent_command::build_agent_command;
use orchestration_hub::command_specification::CommandSpecification;
use proptest::prelude::*;

pub const ALL_AGENTS: [AgentKind; 3] = [
    AgentKind::ClaudeCode,
    AgentKind::Codex,
    AgentKind::GeminiCli,
];
pub const ALL_SANDBOXES: [SandboxKind; 3] = [
    SandboxKind::Container,
    SandboxKind::MicroVirtualMachine,
    SandboxKind::LocalProcess,
];
pub const END_OF_OPTIONS: &str = "--";
pub const GEMINI_PROMPT_OPTION: &str = "--prompt=";
pub const GEMINI_RESUME_OPTION: &str = "--resume=";
pub const CLAUDE_RESUME_OPTION: &str = "--resume";
pub const CODEX_RESUME_COMMAND: &str = "resume";
const UNICODE_SPACES: [char; 8] = [
    ' ', '\t', '\n', '\r', '\u{A0}', '\u{2003}', '\u{3000}', '\u{2028}',
];

pub fn any_agent() -> impl Strategy<Value = AgentKind> {
    proptest::sample::select(ALL_AGENTS.to_vec())
}

pub fn any_sandbox() -> impl Strategy<Value = SandboxKind> {
    proptest::sample::select(ALL_SANDBOXES.to_vec())
}

pub fn any_policy() -> impl Strategy<Value = ApprovalPolicy> {
    prop_oneof![
        Just(ApprovalPolicy::AskBeforeRiskyActions),
        Just(ApprovalPolicy::NeverAsk),
    ]
}

pub fn any_prompt() -> impl Strategy<Value = String> {
    let option_like = "--?[a-z=-]{0,12}( [a-z-]{0,8})?";
    let hostile = "[-=;&|$`'\"()<> a-zé中😀\n\t]{1,40}";
    prop_oneof![
        any::<String>(),
        option_like.prop_map(String::from),
        hostile.prop_map(String::from),
    ]
    .prop_filter("a prompt has text", |prompt| !prompt.trim().is_empty())
}

pub fn any_valid_session() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9][a-zA-Z0-9-]{0,40}"
}

pub fn any_blank_prompt() -> impl Strategy<Value = String> {
    let space = proptest::sample::select(UNICODE_SPACES.to_vec());
    proptest::collection::vec(space, 0..10)
        .prop_map(|spaces| spaces.into_iter().collect())
}

pub fn build_for(
    agent: AgentKind,
    prompt: &str,
    session: Option<&str>,
    sandbox: SandboxKind,
) -> Result<CommandSpecification, TestCaseError> {
    build_agent_command(agent, prompt, session, sandbox)
        .map_err(|problem| TestCaseError::fail(problem.to_string()))
}

pub fn count_equal(arguments: &[String], expected: &str) -> usize {
    arguments
        .iter()
        .filter(|argument| argument.as_str() == expected)
        .count()
}

pub fn find_position(arguments: &[String], expected: &str) -> Option<usize> {
    arguments
        .iter()
        .position(|argument| argument.as_str() == expected)
}

pub fn expected_program(agent: AgentKind) -> &'static str {
    match agent {
        AgentKind::ClaudeCode => "claude",
        AgentKind::Codex => "codex",
        AgentKind::GeminiCli => "gemini",
    }
}

pub fn expected_permission_flags(
    agent: AgentKind,
    sandbox: SandboxKind,
) -> Vec<String> {
    let is_isolated = sandbox != SandboxKind::LocalProcess;
    let flags: &[&str] = match (agent, is_isolated) {
        (AgentKind::ClaudeCode, true) => &["--dangerously-skip-permissions"],
        (AgentKind::ClaudeCode, false) => &["--permission-mode", "auto"],
        (AgentKind::Codex, true) => {
            &["--dangerously-bypass-approvals-and-sandbox"]
        }
        (AgentKind::Codex, false) => &["--sandbox", "workspace-write"],
        (AgentKind::GeminiCli, true) => &["--approval-mode", "yolo"],
        (AgentKind::GeminiCli, false) => &["--approval-mode", "auto_edit"],
    };
    flags.iter().map(ToString::to_string).collect()
}

pub fn list_permission_flag_words() -> Vec<String> {
    let mut words = Vec::new();
    for agent in ALL_AGENTS {
        for sandbox in ALL_SANDBOXES {
            for flag in expected_permission_flags(agent, sandbox) {
                if flag.starts_with(END_OF_OPTIONS) && !words.contains(&flag) {
                    words.push(flag);
                }
            }
        }
    }
    words
}

pub fn contains_in_order(arguments: &[String], expected: &[String]) -> bool {
    arguments
        .windows(expected.len())
        .any(|window| window == expected)
}
