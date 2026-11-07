#[allow(dead_code)]
#[path = "../agent_reading/mod.rs"]
mod agent_reading;
#[allow(dead_code)]
#[path = "../claude_lines/mod.rs"]
mod claude_lines;
#[allow(dead_code)]
#[path = "../agent_streams/codex_lines.rs"]
mod codex_lines;
#[allow(dead_code)]
#[path = "../agent_streams/gemini_lines.rs"]
mod gemini_lines;
#[allow(dead_code)]
#[path = "../json_texts/mod.rs"]
mod json_texts;
#[allow(dead_code)]
#[path = "../agent_streams/stream_support.rs"]
mod stream_support;

mod command_check_properties;
mod command_flag_properties;
mod command_line_properties;
mod command_support;
mod log_event_properties;
mod log_support;
mod log_text_properties;
mod parser_differential_properties;
mod reader_properties;
mod speech_properties;
