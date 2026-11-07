#[allow(dead_code)]
#[path = "../agent_log_lines/mod.rs"]
mod agent_log_lines;
#[allow(dead_code)]
#[path = "../agent_reading/mod.rs"]
mod agent_reading;
#[allow(dead_code)]
#[path = "../claude_lines/mod.rs"]
mod claude_lines;
#[allow(dead_code)]
#[path = "../claude_tool_results/mod.rs"]
mod claude_tool_results;
#[allow(dead_code)]
#[path = "../agent_streams/codex_lines.rs"]
mod codex_lines;
#[allow(dead_code)]
#[path = "../agent_io_properties/command_support.rs"]
mod command_support;
#[allow(dead_code)]
#[path = "../agent_streams/gemini_lines.rs"]
mod gemini_lines;
#[allow(dead_code)]
#[path = "../git_support/mod.rs"]
mod git_support;
#[allow(dead_code)]
#[path = "../json_texts/mod.rs"]
mod json_texts;
#[allow(dead_code)]
#[path = "../agent_streams/stream_support.rs"]
mod stream_support;

mod branch_name_properties;
mod claude_control_properties;
mod claude_result_properties;
mod claude_stream_properties;
mod claude_tool_failure_properties;
mod clone_listing_properties;
mod clone_lock_properties;
mod clone_name_properties;
mod clone_source_properties;
mod codex_change_properties;
mod codex_event_properties;
mod codex_item_properties;
mod terminal_code_nesting_properties;
mod terminal_code_properties;
mod text_shapes;
