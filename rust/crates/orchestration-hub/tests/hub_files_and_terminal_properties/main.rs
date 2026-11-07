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
#[path = "../agent_io_properties/log_support.rs"]
mod log_support;
#[allow(dead_code)]
#[path = "../agent_streams/stream_support.rs"]
mod stream_support;

mod command_label_program_properties;
mod command_label_properties;
mod command_label_support;
mod command_separator_properties;
mod file_preview_properties;
mod folder_removal_properties;
mod gemini_event_properties;
mod gemini_failure_properties;
mod gemini_reading;
mod gemini_speech_properties;
mod held_branch_properties;
mod held_error_properties;
mod held_folders;
mod held_work_properties;
mod image_bytes;
mod image_field_properties;
mod image_format_properties;
mod image_webp_properties;
mod printed_line_log_properties;
mod speech_code_properties;
mod terminal_control_properties;
mod terminal_debug_properties;
mod terminal_output_properties;
mod terminal_support;
