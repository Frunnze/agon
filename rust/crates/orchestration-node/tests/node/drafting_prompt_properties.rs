use orchestration_node::item_drafting::{
    DraftChange, DraftKind, DraftingContext, RepositoryDraft,
    render_drafting_prompt,
};
use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use serde_json::json;

use crate::support::drafting_samples::{
    THIS_DEVICE_ID, context_strategy, describe_kind, empty_context,
    kind_strategy,
};
use crate::support::entity_strategies::secret_text_strategy;
use crate::support::test_device::fail;

const PROMPT_CASES: u32 = 24;
const REPLY_OPENING: &str = "Reply with one JSON object and nothing else.";
const LISTED_IDS_ONLY: &str = "Use only the ids listed above.";
const LOCAL_TIME: &str = "Times are the person's local time.";
const NULL_PROJECT: &str = "Set project_id to null only when several \
                            projects could fit and the request names none.";
const REPO_FORMS: &str = "Write each repo as a GitHub address or the \
                          absolute path of a git folder on this computer.";
const PROJECT_NAME_ADVICE: &str = "Name the project after its first repo or \
                                   folder unless the person names it.";
const CHOSEN_FOLDERS_HEADING: &str =
    "Folders the person chose on this computer (repos of this project):";
const FOLDER_NAME_PATTERN: &str = "[a-z][a-z0-9-]{0,8}";
const MOST_CHOSEN_FOLDERS: usize = 4;

fn expected_explanation(kind: DraftKind) -> &'static str {
    match kind {
        DraftKind::Task => {
            "A task is one piece of work that one agent or a workflow does \
             in a project. If the person wants it to repeat, give it a \
             schedule."
        }
        DraftKind::Job => "A job is a task that repeats on a schedule.",
        DraftKind::Project => {
            "A project names the repos agents work on: GitHub addresses or \
             git folders on this computer."
        }
        DraftKind::Skill => {
            "A skill is instructions agents can use: automatically when the \
             work fits, or only when a task, job or workflow agent chooses \
             it."
        }
        DraftKind::Rule => {
            "A rule is something every agent in its scope must follow. It \
             is written into AGENTS.md."
        }
    }
}

fn expected_fields(kind: DraftKind) -> &'static [&'static str] {
    match kind {
        DraftKind::Task | DraftKind::Job => &[
            "title",
            "details",
            "project_id",
            "doer",
            "runs_on",
            "agent_place",
            "local_process",
            "container",
            "skills",
            "uses_automatic_skills",
            "approval_policy",
            "schedule",
            "ask_before_risky_actions",
            "never_ask",
        ],
        DraftKind::Project => &[
            "name",
            "repositories",
            "address",
            "default_branch",
            "agent_access",
            "read_only",
            "push_after_approval",
        ],
        DraftKind::Skill => &[
            "name",
            "summary",
            "instructions",
            "scope",
            "usage",
            "automatic",
            "when_chosen",
            "improvement",
            "ask_me",
            "only_workspaces",
            "only_projects",
        ],
        DraftKind::Rule => &[
            "title",
            "details",
            "scope",
            "only_workspaces",
            "only_projects",
        ],
    }
}

fn render_plain_prompt(
    context: &DraftingContext,
    kind: DraftKind,
    request: &str,
) -> Result<String, TestCaseError> {
    render_drafting_prompt(context, kind, request, None, None, &[])
        .map_err(fail)
}

fn chosen_folder(path: &str) -> RepositoryDraft {
    RepositoryDraft {
        address: format!("local:{THIS_DEVICE_ID}:{path}"),
        default_branch: "main".to_owned(),
    }
}

fn read_instructions(prompt: &str) -> &str {
    prompt
        .split_once("\n\n")
        .map_or("", |(_, instructions)| instructions)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PROMPT_CASES))]

    #[test]
    fn test_render_drafting_prompt_property_names_the_kind_request_and_ids(
        context in context_strategy(),
        kind in kind_strategy(),
        request in secret_text_strategy(),
    ) {
        let prompt = render_plain_prompt(&context, kind, &request)?;

        let mut lines = prompt.lines();
        let first_line = format!("Draft a new {}.", describe_kind(kind));
        prop_assert_eq!(lines.next(), Some(first_line.as_str()));
        prop_assert_eq!(lines.next(), Some(expected_explanation(kind)));
        let wanted = format!("What the person wants:\n{request}\n\n");
        prop_assert!(prompt.contains(&wanted));
        for project in &context.projects {
            prop_assert!(prompt.contains(&project.id.0.to_string()));
        }
        for workflow in &context.workflows {
            prop_assert!(prompt.contains(&workflow.id.0.to_string()));
        }
        for skill in &context.skills {
            prop_assert!(prompt.contains(&skill.id.0.to_string()));
        }
        for runner in &context.runners {
            let runner_line = format!("- {} (id {})", runner.device.name,
                runner.device.id.0);
            prop_assert!(prompt.contains(&runner_line));
        }
        prop_assert!(!prompt.contains("Started from:"));
        prop_assert!(!prompt.contains("Current draft:"));
        prop_assert!(!prompt.contains(CHOSEN_FOLDERS_HEADING));
    }

    #[test]
    fn test_render_drafting_prompt_property_gives_the_kind_answer_format(
        context in context_strategy(),
        kind in kind_strategy(),
        request in secret_text_strategy(),
    ) {
        let prompt = render_plain_prompt(&context, kind, &request)?;

        let instructions = read_instructions(&prompt);
        prop_assert!(instructions.starts_with(REPLY_OPENING));
        prop_assert!(instructions.contains(LISTED_IDS_ONLY));
        for field in expected_fields(kind) {
            prop_assert!(instructions.contains(field), "{} missing", field);
        }
        let is_work = matches!(kind, DraftKind::Task | DraftKind::Job);
        prop_assert_eq!(instructions.contains(LOCAL_TIME), is_work);
        prop_assert_eq!(instructions.contains(NULL_PROJECT), is_work);
        let is_project = kind == DraftKind::Project;
        prop_assert_eq!(instructions.contains(REPO_FORMS), is_project);
        prop_assert_eq!(
            instructions.contains(PROJECT_NAME_ADVICE),
            is_project
        );
    }

    #[test]
    fn test_render_drafting_prompt_property_adds_started_from_and_change(
        context in context_strategy(),
        kind in kind_strategy(),
        request in secret_text_strategy(),
        started_from in secret_text_strategy(),
        note in secret_text_strategy(),
    ) {
        let draft = json!({ "title": started_from, "skills": [] });
        let change = DraftChange { draft: draft.clone(), note: note.clone() };

        let prompt = render_drafting_prompt(
            &context,
            kind,
            &request,
            Some(&started_from),
            Some(&change),
            &[],
        )
        .map_err(fail)?;

        let pretty_draft = serde_json::to_string_pretty(&draft).map_err(fail)?;
        let expected_part = format!(
            "\nStarted from: {started_from}\nWhat the person wants:\n\
             {request}\nCurrent draft:\n{pretty_draft}\nRequested change:\n\
             {note}\n\n{REPLY_OPENING}"
        );
        prop_assert!(prompt.contains(&expected_part), "{}", prompt);
    }

    #[test]
    fn test_render_drafting_prompt_property_marks_empty_sections_with_none(
        kind in kind_strategy(),
        request in secret_text_strategy(),
    ) {
        let context = empty_context();

        let prompt = render_plain_prompt(&context, kind, &request)?;

        let empty_sections = "\nProjects:\n- none\nWorkflows:\n- none\n\
                              Skills:\n- none\nRunners:\n- none\n";
        prop_assert!(prompt.contains(empty_sections), "{}", prompt);
    }

    #[test]
    fn test_render_drafting_prompt_property_lists_every_chosen_folder_path(
        context in context_strategy(),
        request in secret_text_strategy(),
        names in proptest::collection::vec(
            FOLDER_NAME_PATTERN,
            1..MOST_CHOSEN_FOLDERS,
        ),
        note in secret_text_strategy(),
    ) {
        let paths: Vec<String> =
            names.iter().map(|name| format!("/Users/someone/{name}")).collect();
        let folders: Vec<RepositoryDraft> =
            paths.iter().map(|path| chosen_folder(path)).collect();
        let change = DraftChange { draft: json!({}), note };

        let prompt = render_drafting_prompt(
            &context,
            DraftKind::Project,
            &request,
            None,
            Some(&change),
            &folders,
        )
        .map_err(fail)?;

        let folder_lines: Vec<String> =
            paths.iter().map(|path| format!("- {path}")).collect();
        let expected_part = format!(
            "What the person wants:\n{request}\n{CHOSEN_FOLDERS_HEADING}\n\
             {}\nCurrent draft:\n",
            folder_lines.join("\n")
        );
        prop_assert!(prompt.contains(&expected_part), "{}", prompt);
    }
}
