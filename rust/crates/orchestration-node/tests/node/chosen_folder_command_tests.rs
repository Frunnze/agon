use proptest::prelude::*;
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::support::command_builders::PreparedWorkspace;
use crate::support::drafting_desk::{DraftingDesk, open_desk_or_panic};
use crate::support::git_folders::create_git_folder;
use crate::support::item_drafting_desk::{
    draft_item_command, drafted_project_answer, finish_item_draft,
    item_draft_status, read_device_id, start_item_draft,
};
use crate::support::test_device::fail;

const FOLDER_CASES: u32 = 4;
const BRANCH_PATTERN: &str = "[a-z][a-z0-9-]{0,8}[a-z0-9]";
const AGENT_ADDRESS: &str = "github.com/acme/billing";
const FOREIGN_DEVICE_ID: &str = "f0f0f0";
const CHOSEN_FOLDERS_HEADING: &str =
    "Folders the person chose on this computer (repos of this project):";
const OTHER_KINDS: [&str; 4] = ["task", "job", "skill", "rule"];
const UNKNOWN_TASK_ID: &str = "00000000-0000-0000-0000-0000deadbeef";

fn chosen_folder(address: &str, branch: &str) -> Value {
    json!({ "address": address, "default_branch": branch })
}

fn draft_with_folders(
    prepared: &PreparedWorkspace,
    kind: &str,
    chosen_folders: Value,
) -> Value {
    let mut command = draft_item_command(prepared, kind, "Billing");
    command["chosen_folders"] = chosen_folders;
    command
}

fn is_seen_by_server(desk: &DraftingDesk, text: &str) -> bool {
    let requests = desk.prepared.server.recorded_requests();
    for recorded in &requests {
        if String::from_utf8_lossy(&recorded.body).contains(text) {
            return true;
        }
    }
    false
}

fn this_device_id(desk: &DraftingDesk) -> String {
    match read_device_id(&desk.prepared.device) {
        Ok(device_id) => device_id,
        Err(message) => panic!("the device id is read: {message}"),
    }
}

fn temporary_folder() -> TempDir {
    match TempDir::new() {
        Ok(folder) => folder,
        Err(error) => panic!("the temporary folder is made: {error}"),
    }
}

#[test]
fn draft_item_refuses_folders_that_are_not_git_folders_here() {
    let desk = open_desk_or_panic();
    let device_id = this_device_id(&desk);
    let parent = temporary_folder();
    let path = parent.path().display().to_string();
    let refusals = [
        (
            AGENT_ADDRESS.to_owned(),
            format!(
                "a local address is local:<device id>:<folder>, not \
                 \"{AGENT_ADDRESS}\""
            ),
        ),
        (
            format!("local:{FOREIGN_DEVICE_ID}:{path}"),
            format!(
                "the folder {path} is on another computer, so add it there"
            ),
        ),
        (
            format!("local:{device_id}:{path}/missing"),
            format!(
                "the folder {path}/missing does not exist or this app cannot \
                 open it"
            ),
        ),
        (
            format!("local:{device_id}:{path}"),
            format!("the folder {path} is not a git repository"),
        ),
    ];

    for (address, expected) in refusals {
        let chosen = json!([chosen_folder(&address, "main")]);
        let command = draft_with_folders(&desk.prepared, "project", chosen);

        let refused = desk.prepared.device.run(&command);

        assert_eq!(refused, Err(expected));
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FOLDER_CASES))]

    #[test]
    fn test_item_draft_status_property_adds_the_folders_the_agent_left_out(
        branch in BRANCH_PATTERN,
    ) {
        let desk = open_desk_or_panic();
        let device_id = this_device_id(&desk);
        let parent = TempDir::new().map_err(fail)?;
        let folder =
            create_git_folder(parent.path(), &branch).map_err(fail)?;
        let path = folder.display().to_string();
        let address = format!("local:{device_id}:{path}");
        let chosen = json!([chosen_folder(&address, &branch)]);
        let command = draft_with_folders(&desk.prepared, "project", chosen);
        let draft = start_item_draft(&desk, &command).map_err(fail)?;
        let answer = drafted_project_answer(AGENT_ADDRESS).to_string();
        finish_item_draft(&desk, &draft, &answer).map_err(fail)?;

        let status = item_draft_status(&desk, &draft);

        let listed = format!("{CHOSEN_FOLDERS_HEADING}\n- {path}\n");
        prop_assert!(draft.details.contains(&listed), "{}", draft.details);
        prop_assert!(!is_seen_by_server(&desk, &path));
        let expected = json!([
            chosen_folder(AGENT_ADDRESS, "main"),
            chosen_folder(&address, &branch),
        ]);
        prop_assert_eq!(&status["ok"]["draft"]["repositories"], &expected);
        prop_assert_eq!(&status["ok"]["problems"], &json!([]));
    }

    #[test]
    fn test_draft_item_property_only_a_project_takes_chosen_folders(
        kind in proptest::sample::select(OTHER_KINDS.to_vec()),
    ) {
        let desk = open_desk_or_panic();
        let device_id = this_device_id(&desk);
        let parent = TempDir::new().map_err(fail)?;
        let folder = create_git_folder(parent.path(), "main").map_err(fail)?;
        let address = format!("local:{device_id}:{}", folder.display());
        let chosen = json!([chosen_folder(&address, "main")]);
        let command = draft_with_folders(&desk.prepared, kind, chosen.clone());

        let refused_draft = desk.prepared.device.run(&command);
        let refused_status = desk.prepared.device.run(&json!({
            "command": "item_draft_status",
            "workspace_id": desk.prepared.workspace_id,
            "task_id": UNKNOWN_TASK_ID,
            "kind": kind,
            "chosen_folders": chosen,
        }));

        let expected =
            format!("only a project draft takes chosen folders, not a {kind}");
        prop_assert_eq!(refused_draft, Err(expected.clone()));
        prop_assert_eq!(refused_status, Err(expected));
    }
}
