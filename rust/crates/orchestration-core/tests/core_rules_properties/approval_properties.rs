use orchestration_core::approval::{
    ApprovalAction, ApprovalDecision, ApprovalPolicy, ApprovalRequest,
    SignedDecision, UNLABELLED_COMMAND_SUMMARY,
};
use orchestration_core::identifiers::{
    ApprovalId, DeviceId, RunId, SkillId, WorkflowId,
};
use proptest::collection::vec;
use proptest::option;
use proptest::prelude::*;
use serde_json::{Value, json};
use uuid::Uuid;

use crate::entity_strategies::{device_identifier, ordinary_timestamp};

const MAXIMUM_COMMITS: usize = 3;
const MAXIMUM_SIGNATURE_LENGTH: usize = 8;
const KIND_FIELD: &str = "kind";
const SUMMARY_FIELD: &str = "summary";

fn approval_action() -> impl Strategy<Value = ApprovalAction> {
    prop_oneof![
        (".*", ".*", vec(".*", 0..MAXIMUM_COMMITS)).prop_map(
            |(repository, branch, commits)| ApprovalAction::PushCommits {
                repository,
                branch,
                commits,
            }
        ),
        ".*".prop_map(|target| ApprovalAction::Deploy { target }),
        (".*", ".*").prop_map(|(repository, what)| {
            ApprovalAction::DeleteBranchOrFiles { repository, what }
        }),
        any::<u128>().prop_map(|number| ApprovalAction::SignWorkflow {
            workflow_id: WorkflowId(Uuid::from_u128(number)),
        }),
        (".*", ".*", ".*").prop_map(|(tool, summary, command)| {
            ApprovalAction::RunCommand {
                tool,
                summary,
                command,
            }
        }),
        (any::<u128>(), ".*", ".*").prop_map(
            |(number, summary, proposed_instructions)| {
                ApprovalAction::ImproveSkill {
                    skill_id: SkillId(Uuid::from_u128(number)),
                    summary,
                    proposed_instructions,
                }
            }
        ),
    ]
}

fn signed_decision() -> impl Strategy<Value = SignedDecision> {
    (
        prop_oneof![
            Just(ApprovalDecision::Approved),
            Just(ApprovalDecision::Denied)
        ],
        device_identifier(),
        ordinary_timestamp(),
        vec(any::<u8>(), 0..MAXIMUM_SIGNATURE_LENGTH),
    )
        .prop_map(|(decision, decided_by, decided_at, signature)| {
            SignedDecision {
                decision,
                decided_by,
                decided_at,
                signature,
            }
        })
}

fn approval_request() -> impl Strategy<Value = ApprovalRequest> {
    (
        any::<u128>(),
        option::of(any::<u128>()),
        approval_action(),
        ".*",
        ordinary_timestamp(),
        option::of(signed_decision()),
    )
        .prop_map(
            |(number, run_number, action, device, requested_at, decision)| {
                ApprovalRequest {
                    id: ApprovalId(Uuid::from_u128(number)),
                    run_id: run_number.map(|run| RunId(Uuid::from_u128(run))),
                    action,
                    requested_by: DeviceId(device),
                    requested_at,
                    decision,
                }
            },
        )
}

fn fail_with(error: &serde_json::Error) -> TestCaseError {
    TestCaseError::fail(error.to_string())
}

fn read_action(stored: Value) -> Result<ApprovalAction, serde_json::Error> {
    serde_json::from_value(stored)
}

proptest! {
    #[test]
    fn test_name_unlabelled_command_property_fills_a_missing_summary(
        tool in ".*",
        command in ".*",
    ) {
        let stored = json!({
            KIND_FIELD: "run_command",
            "tool": tool,
            "command": command,
        });

        let action = read_action(stored).map_err(|error| fail_with(&error))?;

        prop_assert_eq!(action, ApprovalAction::RunCommand {
            tool,
            summary: UNLABELLED_COMMAND_SUMMARY.to_owned(),
            command,
        });
    }

    #[test]
    fn test_name_unlabelled_command_property_keeps_any_written_summary(
        tool in ".*",
        summary in ".*",
        command in ".*",
    ) {
        let stored = json!({
            KIND_FIELD: "run_command",
            "tool": tool,
            SUMMARY_FIELD: summary,
            "command": command,
        });

        let action = read_action(stored).map_err(|error| fail_with(&error))?;

        prop_assert_eq!(action, ApprovalAction::RunCommand {
            tool,
            summary,
            command,
        });
    }

    #[test]
    fn test_name_unlabelled_command_property_skill_summaries_stay_required(
        number in any::<u128>(),
        proposed_instructions in ".*",
    ) {
        let stored = json!({
            KIND_FIELD: "improve_skill",
            "skill_id": Uuid::from_u128(number),
            "proposed_instructions": proposed_instructions,
        });

        prop_assert!(read_action(stored).is_err());
    }

    #[test]
    fn test_approval_action_serde_property_round_trips_with_a_kind_tag(
        action in approval_action(),
    ) {
        let encoded =
            serde_json::to_value(&action).map_err(|error| fail_with(&error))?;
        let kind = encoded.get(KIND_FIELD).and_then(Value::as_str);

        let decoded = read_action(encoded.clone())
            .map_err(|error| fail_with(&error))?;

        let is_snake_case_kind = kind.is_some_and(|kind| {
            !kind.is_empty()
                && kind.chars().all(|letter| {
                    letter.is_ascii_lowercase() || letter == '_'
                })
        });
        prop_assert_eq!(decoded, action);
        prop_assert!(is_snake_case_kind);
    }

    #[test]
    fn test_approval_policy_serde_property_missing_choice_never_asks(
        choice in option::of(prop_oneof![
            Just(ApprovalPolicy::AskBeforeRiskyActions),
            Just(ApprovalPolicy::NeverAsk),
        ]),
    ) {
        let resolved = choice.unwrap_or_default();

        let encoded =
            serde_json::to_value(resolved).map_err(|error| fail_with(&error))?;
        let decoded: ApprovalPolicy = serde_json::from_value(encoded)
            .map_err(|error| fail_with(&error))?;

        prop_assert_eq!(decoded, resolved);
        if choice.is_none() {
            prop_assert_eq!(resolved, ApprovalPolicy::NeverAsk);
        }
    }

    #[test]
    fn test_approval_request_serde_property_round_trips_every_field(
        request in approval_request(),
    ) {
        let encoded = serde_json::to_string(&request)
            .map_err(|error| fail_with(&error))?;
        let decoded: ApprovalRequest = serde_json::from_str(&encoded)
            .map_err(|error| fail_with(&error))?;

        prop_assert_eq!(decoded, request);
    }
}
