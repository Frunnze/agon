#[allow(dead_code)]
#[path = "../git_support/mod.rs"]
mod git_support;
#[allow(dead_code)]
#[path = "../hub_files_and_terminal_properties/held_folders.rs"]
mod held_folders;
#[allow(dead_code)]
#[path = "../text_and_worktree_properties/worktree_folders.rs"]
mod worktree_folders;
#[allow(dead_code)]
#[path = "../worktree_support/mod.rs"]
mod worktree_support;

mod kept_branch_command_properties;
mod kept_branch_recovery_properties;
mod kept_branch_safety_properties;
mod recovery_support;
