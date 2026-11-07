#[allow(dead_code)]
#[path = "../agent_reading/mod.rs"]
mod agent_reading;
#[allow(dead_code)]
#[path = "../agent_streams/codex_lines.rs"]
mod codex_lines;
#[allow(dead_code)]
#[path = "../git_support/mod.rs"]
mod git_support;
#[allow(dead_code)]
#[path = "../json_texts/mod.rs"]
mod json_texts;
#[allow(dead_code)]
#[path = "../sandbox_support/mod.rs"]
mod sandbox_support;
#[allow(dead_code)]
#[path = "../agent_streams/stream_support.rs"]
mod stream_support;

mod clone_folder_length_properties;
mod clone_name_shortening_properties;
mod clone_name_support;
mod codex_failed_patch_properties;
mod cover_support;
mod group_existence_properties;
mod group_killer_properties;
mod group_leader_properties;
mod group_signal_properties;
mod group_stopping;
mod group_support;
mod json_line_properties;
mod keep_awake_properties;
mod leftover_removal_properties;
mod leftover_support;
mod own_group_properties;
mod piped_process_properties;
mod placeholder_emptiness_properties;
mod placeholder_mount_properties;
mod process_output_properties;
mod process_support;
mod protected_cover_properties;
mod protected_entry_properties;
mod supervisor_error_properties;
mod target_folders;
mod terminal_process_properties;
mod working_folder_properties;
