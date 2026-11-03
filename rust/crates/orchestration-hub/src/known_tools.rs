use crate::tool_description::{DetailKind, KnownTool, define_known_tool};

pub(crate) const CLAUDE_TOOLS: [KnownTool; 10] = [
    define_known_tool("Bash", "command", "Ran", DetailKind::Text),
    define_known_tool("Edit", "file_path", "Edited", DetailKind::FilePath),
    define_known_tool(
        "MultiEdit",
        "file_path",
        "Edited",
        DetailKind::FilePath,
    ),
    define_known_tool(
        "NotebookEdit",
        "notebook_path",
        "Edited",
        DetailKind::FilePath,
    ),
    define_known_tool("Write", "file_path", "Wrote", DetailKind::FilePath),
    define_known_tool("Read", "file_path", "Read", DetailKind::FilePath),
    define_known_tool("Grep", "pattern", "Searched for", DetailKind::Text),
    define_known_tool(
        "Glob",
        "pattern",
        "Looked for files matching",
        DetailKind::Text,
    ),
    define_known_tool("WebFetch", "url", "Fetched", DetailKind::Text),
    define_known_tool(
        "WebSearch",
        "query",
        "Searched the web for",
        DetailKind::Text,
    ),
];

pub(crate) const GEMINI_TOOLS: [KnownTool; 8] = [
    define_known_tool("run_shell_command", "command", "Ran", DetailKind::Text),
    define_known_tool("replace", "file_path", "Edited", DetailKind::FilePath),
    define_known_tool(
        "write_file",
        "file_path",
        "Wrote",
        DetailKind::FilePath,
    ),
    define_known_tool("read_file", "file_path", "Read", DetailKind::FilePath),
    define_known_tool(
        "list_directory",
        "dir_path",
        "Listed",
        DetailKind::FilePath,
    ),
    define_known_tool(
        "grep_search",
        "pattern",
        "Searched for",
        DetailKind::Text,
    ),
    define_known_tool(
        "glob",
        "pattern",
        "Looked for files matching",
        DetailKind::Text,
    ),
    define_known_tool(
        "google_web_search",
        "query",
        "Searched the web for",
        DetailKind::Text,
    ),
];
