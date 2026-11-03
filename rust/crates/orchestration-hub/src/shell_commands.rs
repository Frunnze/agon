const LOGIN_SHELL_OPTION: &str = " -lc ";
const SHELL_NAMES: [&str; 3] = ["bash", "zsh", "sh"];
const QUOTES: [char; 2] = ['\'', '"'];
const PATH_SEPARATOR: char = '/';

pub(crate) fn unwrap_shell_command(command: &str) -> &str {
    let trimmed_command = command.trim();
    let Some((shell, script)) = trimmed_command.split_once(LOGIN_SHELL_OPTION)
    else {
        return trimmed_command;
    };

    let shell_name = shell.rsplit(PATH_SEPARATOR).next().unwrap_or_default();
    if !SHELL_NAMES.contains(&shell_name) {
        return trimmed_command;
    }
    strip_surrounding_quotes(script.trim())
}

fn strip_surrounding_quotes(script: &str) -> &str {
    for quote in QUOTES {
        let inside_quotes = script
            .strip_prefix(quote)
            .and_then(|rest| rest.strip_suffix(quote));
        if let Some(quoted_script) = inside_quotes {
            return quoted_script;
        }
    }
    script
}
