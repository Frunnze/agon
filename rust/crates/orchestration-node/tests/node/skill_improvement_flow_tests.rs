use orchestration_api::catalog::ImproveSkillRequest;
use orchestration_core::identifiers::SkillId;
use orchestration_runner::runner_server::RunnerServer;
use serde_json::{Value, json};
use uuid::Uuid;

use crate::support::command_builders::{
    create_skill_command, prepare_workspace,
};
use crate::support::runner_access::{
    ClaimedRun, claim_started_task, started_task_command,
};
use crate::support::test_device::{describe, read_text};

const TASK_DETAILS: &str = "task details only devices can read";
const FIRST_INSTRUCTIONS: &str = "first instructions only devices can read";
const PROPOSED_INSTRUCTIONS: &str = "proposed version only devices can read";
const SUMMARY: &str = "1 line added, 1 line removed";

#[derive(Debug)]
struct ImprovableRun {
    claimed: ClaimedRun,
    skill_id: String,
}

fn claim_with_skill(improvement: &str) -> Result<ImprovableRun, String> {
    let prepared = prepare_workspace()?;
    let mut skill_command =
        create_skill_command(&prepared.workspace_id, FIRST_INSTRUCTIONS);
    skill_command["improvement"] = json!(improvement);
    let skill = prepared.device.run(&skill_command)?;
    let skill_id = read_text(&skill, "/id")?;
    let task_command = started_task_command(&prepared, TASK_DETAILS);
    let claimed = claim_started_task(prepared, &task_command)?;
    Ok(ImprovableRun { claimed, skill_id })
}

fn claim_or_panic(improvement: &str) -> ImprovableRun {
    match claim_with_skill(improvement) {
        Ok(improvable) => improvable,
        Err(message) => panic!("a run is claimed: {message}"),
    }
}

fn propose(improvable: &ImprovableRun) -> Result<(), String> {
    let skill_uuid =
        Uuid::parse_str(&improvable.skill_id).map_err(describe)?;
    let request = ImproveSkillRequest {
        run_id: improvable.claimed.assignment.run.id,
        summary: SUMMARY.to_owned(),
        instructions: PROPOSED_INSTRUCTIONS.to_owned(),
    };
    let claimed = &improvable.claimed;
    let proposing = claimed
        .runner
        .propose_skill_improvement(SkillId(skill_uuid), &request);
    claimed.runtime.block_on(proposing).map_err(describe)
}

fn run_command(improvable: &ImprovableRun, command: &Value) -> Value {
    match improvable.claimed.prepared.device.run(command) {
        Ok(reply) => reply,
        Err(message) => panic!("the command {command} runs: {message}"),
    }
}

fn listed_skill(improvable: &ImprovableRun) -> Value {
    let skills = run_command(
        improvable,
        &json!({
            "command": "list_skills",
            "workspace_id": improvable.claimed.prepared.workspace_id,
        }),
    );
    skills[0].clone()
}

fn list_approvals(improvable: &ImprovableRun) -> Value {
    run_command(improvable, &json!({ "command": "list_approvals" }))
}

fn decide_first_approval(improvable: &ImprovableRun, decision: &str) {
    let approvals = list_approvals(improvable);
    run_command(
        improvable,
        &json!({
            "command": "decide_approval",
            "approval_id": approvals["approvals"][0]["approval"]["id"],
            "decision": decision,
        }),
    );
}

fn assert_only_ciphertext_is_stored(improvable: &ImprovableRun) {
    let stored = improvable.claimed.prepared.server.read_stored_state();
    let Ok(stored_state) = stored else {
        panic!("the server state is readable");
    };
    assert!(!stored_state.contains(FIRST_INSTRUCTIONS));
    assert!(!stored_state.contains(PROPOSED_INSTRUCTIONS));
}

fn run_id_text(improvable: &ImprovableRun) -> Value {
    json!(improvable.claimed.assignment.run.id.0.to_string())
}

#[test]
fn never_refuses_the_proposal_and_keeps_the_skill() {
    let improvable = claim_or_panic("never");

    let proposed = propose(&improvable);

    assert!(proposed.is_err());
    let skill = listed_skill(&improvable);
    assert_eq!(skill["instructions"], FIRST_INSTRUCTIONS);
    assert_eq!(skill["history"], json!([]));
}

#[test]
fn auto_saves_the_sealed_version_with_its_run_and_undo_restores_it() {
    let improvable = claim_or_panic("auto");

    let proposed = propose(&improvable);

    assert_eq!(proposed, Ok(()));
    let skill = listed_skill(&improvable);
    assert_eq!(skill["instructions"], PROPOSED_INSTRUCTIONS);
    let change = &skill["history"][0];
    assert_eq!(change["origin"]["kind"], "automatic_agent_run");
    assert_eq!(change["origin"]["run_id"], run_id_text(&improvable));
    assert_eq!(change["replaced_instructions"], FIRST_INSTRUCTIONS);
    assert_only_ciphertext_is_stored(&improvable);

    let restored = run_command(
        &improvable,
        &json!({
            "command": "undo_skill_change",
            "skill_id": improvable.skill_id,
        }),
    );

    assert_eq!(restored["instructions"], FIRST_INSTRUCTIONS);
    assert_eq!(listed_skill(&improvable)["history"], json!([]));
}

#[test]
fn ask_me_shows_the_opened_diff_and_approving_saves_it() {
    let improvable = claim_or_panic("ask_me");

    let proposed = propose(&improvable);

    assert_eq!(proposed, Ok(()));
    assert_eq!(
        listed_skill(&improvable)["instructions"],
        FIRST_INSTRUCTIONS
    );
    let approvals = list_approvals(&improvable);
    let shown = &approvals["approvals"][0];
    assert_eq!(shown["approval"]["action"]["kind"], "improve_skill");
    assert_eq!(shown["approval"]["action"]["summary"], SUMMARY);
    assert_eq!(
        shown["approval"]["action"]["proposed_instructions"],
        PROPOSED_INSTRUCTIONS
    );
    assert_eq!(shown["skill_change"]["skill_name"], "release-notes");
    let expected_changes = json!([
        { "removed": FIRST_INSTRUCTIONS },
        { "added": PROPOSED_INSTRUCTIONS },
    ]);
    assert_eq!(shown["skill_change"]["changes"], expected_changes);
    assert_only_ciphertext_is_stored(&improvable);

    decide_first_approval(&improvable, "approved");

    let skill = listed_skill(&improvable);
    assert_eq!(skill["instructions"], PROPOSED_INSTRUCTIONS);
    let origin = &skill["history"][0]["origin"];
    assert_eq!(origin["kind"], "approved_agent_run");
    assert_eq!(origin["run_id"], run_id_text(&improvable));
}

#[test]
fn ask_me_denied_keeps_the_skill() {
    let improvable = claim_or_panic("ask_me");
    let Ok(()) = propose(&improvable) else {
        panic!("the proposal is handed over");
    };

    decide_first_approval(&improvable, "denied");

    let skill = listed_skill(&improvable);
    assert_eq!(skill["instructions"], FIRST_INSTRUCTIONS);
    assert_eq!(skill["history"], json!([]));
}

#[test]
fn an_edit_that_keeps_the_instructions_adds_no_history() {
    let improvable = claim_or_panic("auto");
    let skill = listed_skill(&improvable);
    let mut edit = json!({
        "command": "update_skill",
        "workspace_id": improvable.claimed.prepared.workspace_id,
        "skill_id": improvable.skill_id,
        "name": "release-notes",
        "summary": "Changed summary",
        "instructions": skill["instructions"],
        "scope": skill["scope"],
        "usage": "automatic",
        "improvement": "ask_me",
    });

    run_command(&improvable, &edit);
    let renamed = listed_skill(&improvable);
    edit["instructions"] = json!(PROPOSED_INSTRUCTIONS);
    run_command(&improvable, &edit);
    let edited = listed_skill(&improvable);

    assert_eq!(renamed["history"], json!([]));
    assert_eq!(renamed["improvement"], "ask_me");
    assert_eq!(edited["history"][0]["origin"]["kind"], "person_edit");
    assert_eq!(
        edited["history"][0]["replaced_instructions"],
        FIRST_INSTRUCTIONS
    );
}
