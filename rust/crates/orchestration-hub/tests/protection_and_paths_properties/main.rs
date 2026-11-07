#[allow(dead_code)]
#[path = "../git_support/mod.rs"]
mod git_support;
#[allow(dead_code)]
#[path = "../hub_files_and_terminal_properties/terminal_support.rs"]
mod terminal_support;

mod expression_differential_properties;
mod expression_glob_properties;
mod expression_place_properties;
mod hook_running;
mod hook_shape_properties;
mod path_spelling;
mod repository_branch_properties;
mod repository_copies;
mod repository_file_properties;
mod repository_git_properties;
mod repository_listing_properties;
mod requested_action_properties;
mod requested_action_support;
mod requested_field_properties;
mod run_activity_properties;
mod safe_path_properties;
mod settings_properties;
mod terminal_child_properties;
mod terminal_stop_properties;
