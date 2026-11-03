use orchestration_core::naming::MAXIMUM_NAME_LENGTH;

use super::draft_kind::DraftKind;

const REPLY_OPENING: &str = "Reply with one JSON object and nothing else.";
const FIELDS_HEADING: &str = "Its fields:";
const LISTED_IDS_ONLY: &str = "Use only the ids listed above.";
pub(crate) const RUNS_ON_FORMS: &str = "{\"kind\": \"any_free_runner\"}, \
     {\"kind\": \"specific_runner\", \"device_id\": \"<id>\"} or \
     {\"kind\": \"runner_with_labels\", \"labels\": [\"<label>\"]}";
pub(crate) const APPROVAL_POLICY_FORMS: &str = "ask_before_risky_actions \
     (ask the person before each command and push) or never_ask (run \
     without asking)";
const WORK_OPENING_LINES: [&str; 4] = [
    "- title: what should be done, in a few words.",
    "- details: everything the agent needs to know to do it.",
    "- project_id: the id of the project the work belongs to. Pick the \
     project that fits best; when only one project is listed, use it.",
    "- doer: {\"kind\": \"one_agent\", \"agent\": \"claude_code\"} with \
     agent claude_code, codex or gemini_cli, or {\"kind\": \"workflow\", \
     \"workflow_id\": \"<id>\"} with a signed workflow. claude_code when \
     the person names no agent or workflow.",
];
const WORK_PLACE_AND_SKILL_LINES: [&str; 3] = [
    "- agent_place: where its agents run, local_process (on the runner's \
     computer) or container (in Docker, a new container per run). Pick a \
     place the runners above offer; local_process when unsure.",
    "- skills: a list of the ids of skills the agent should use, or [] \
     when none fits.",
    "- uses_automatic_skills: true or false, whether automatic skills \
     apply too; true when unsure.",
];
const RUNS_ON_ADVICE: &str =
    "any_free_runner unless the person names a runner or a label";
const APPROVAL_ADVICE: &str =
    "ask_before_risky_actions unless the person says otherwise";
const SCHEDULE_FORMS: &str = "{\"every\": \"hour\", \"minute\": 0-59}, \
     {\"every\": \"day\", \"at\": {\"hour\": 0-23, \"minute\": 0-59}} or \
     {\"every\": \"week\", \"on\": \"Mon\", \"at\": {\"hour\": 0-23, \
     \"minute\": 0-59}}, where on is Mon, Tue, Wed, Thu, Fri, Sat or Sun";
const TASK_SCHEDULE_OPENING: &str = "- schedule: null, or how often it \
                                     repeats:";
const JOB_SCHEDULE_OPENING: &str = "- schedule: how often it repeats, never \
                                    null:";
const WORK_RULE_LINES: [&str; 2] = [
    "Set project_id to null only when several projects could fit and the \
     request names none.",
    "Times are the person's local time.",
];
const PROJECT_FIELD_LINES: [&str; 2] = [
    "- repositories: a list of {\"address\": \"<repo>\", \
     \"default_branch\": \"<branch>\"}, with main when the branch is not \
     known.",
    "- agent_access: read_only or push_after_approval; \
     push_after_approval unless the person says read only.",
];
const REPOSITORY_FORMS: &str = "Write each repo as a GitHub address or the \
                                absolute path of a git folder on this \
                                computer.";
const SKILL_FIELD_LINES: [&str; 2] = [
    "- summary: one sentence on what the skill does.",
    "- instructions: the full instructions agents follow.",
];
const SKILL_USAGE_LINE: &str = "- usage: automatic or when_chosen.";
const RULE_FIELD_LINES: [&str; 2] = [
    "- title: the rule in one short sentence.",
    "- details: more about the rule, or an empty text.",
];
const SCOPE_LINE: &str = "- scope: {\"workspaces\": W, \"projects\": P}, \
     where W is {\"kind\": \"all_workspaces\"} or {\"kind\": \
     \"only_workspaces\", \"workspaces\": [\"<id>\"]} and P is {\"kind\": \
     \"all_projects\"} or {\"kind\": \"only_projects\", \"projects\": \
     [\"<id>\"]}.";

pub(super) fn render_format_instructions(kind: DraftKind) -> String {
    let mut lines = vec![REPLY_OPENING.to_owned(), FIELDS_HEADING.to_owned()];
    lines.extend(list_kind_lines(kind));
    lines.push(LISTED_IDS_ONLY.to_owned());
    lines.join("\n")
}

fn list_kind_lines(kind: DraftKind) -> Vec<String> {
    match kind {
        DraftKind::Task => list_work_lines(TASK_SCHEDULE_OPENING),
        DraftKind::Job => list_work_lines(JOB_SCHEDULE_OPENING),
        DraftKind::Project => {
            let mut lines = vec![describe_name_field(kind)];
            lines.extend(own_lines(&PROJECT_FIELD_LINES));
            lines.push(REPOSITORY_FORMS.to_owned());
            lines
        }
        DraftKind::Skill => {
            let mut lines = vec![describe_name_field(kind)];
            lines.extend(own_lines(&SKILL_FIELD_LINES));
            lines.push(SCOPE_LINE.to_owned());
            lines.push(SKILL_USAGE_LINE.to_owned());
            lines
        }
        DraftKind::Rule => {
            let mut lines = own_lines(&RULE_FIELD_LINES);
            lines.push(SCOPE_LINE.to_owned());
            lines
        }
    }
}

fn list_work_lines(schedule_opening: &str) -> Vec<String> {
    let mut lines = own_lines(&WORK_OPENING_LINES);
    lines.push(format!("- runs_on: {RUNS_ON_FORMS}; {RUNS_ON_ADVICE}."));
    lines.extend(own_lines(&WORK_PLACE_AND_SKILL_LINES));
    lines.push(format!(
        "- approval_policy: {APPROVAL_POLICY_FORMS}; {APPROVAL_ADVICE}."
    ));
    lines.push(format!("{schedule_opening} {SCHEDULE_FORMS}."));
    lines.extend(own_lines(&WORK_RULE_LINES));
    lines
}

fn describe_name_field(kind: DraftKind) -> String {
    format!(
        "- name: lowercase letters, digits and dashes, at most \
         {MAXIMUM_NAME_LENGTH} characters, and no {} above has it.",
        kind.name()
    )
}

fn own_lines(lines: &[&str]) -> Vec<String> {
    lines.iter().map(|line| (*line).to_owned()).collect()
}
