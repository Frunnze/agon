use orchestration_core::approval::{ApprovalAction, ApprovalPolicy};
use orchestration_core::approval_policy::needs_approval;
use orchestration_core::identifiers::WorkflowId;
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

const MAXIMUM_COMMITS: usize = 4;

fn approval_action() -> impl Strategy<Value = ApprovalAction> {
    prop_oneof![
        (
            any::<String>(),
            any::<String>(),
            vec(any::<String>(), 0..MAXIMUM_COMMITS)
        )
            .prop_map(|(repository, branch, commits)| {
                ApprovalAction::PushCommits {
                    repository,
                    branch,
                    commits,
                }
            }),
        any::<String>().prop_map(|target| ApprovalAction::Deploy { target }),
        (any::<String>(), any::<String>()).prop_map(|(repository, what)| {
            ApprovalAction::DeleteBranchOrFiles { repository, what }
        }),
        sign_workflow_action(),
    ]
}

fn approval_policy() -> impl Strategy<Value = ApprovalPolicy> {
    prop_oneof![
        Just(ApprovalPolicy::AskBeforeRiskyActions),
        Just(ApprovalPolicy::NeverAsk),
    ]
}

fn sign_workflow_action() -> impl Strategy<Value = ApprovalAction> {
    any::<u128>().prop_map(|number| ApprovalAction::SignWorkflow {
        workflow_id: WorkflowId(Uuid::from_u128(number)),
    })
}

proptest! {
    #[test]
    fn test_needs_approval_property_signing_a_workflow_always_needs_it(
        policy in approval_policy(),
        action in sign_workflow_action(),
    ) {
        prop_assert!(needs_approval(policy, &action));
    }

    #[test]
    fn test_needs_approval_property_asking_agents_need_it_for_every_action(
        action in approval_action(),
    ) {
        let asking = ApprovalPolicy::AskBeforeRiskyActions;

        prop_assert!(needs_approval(asking, &action));
    }

    #[test]
    fn test_needs_approval_property_silent_agents_skip_it_except_signing(
        action in approval_action(),
    ) {
        let is_signing = matches!(action, ApprovalAction::SignWorkflow { .. });

        let needs_it = needs_approval(ApprovalPolicy::NeverAsk, &action);

        prop_assert_eq!(needs_it, is_signing);
    }

    #[test]
    fn test_needs_approval_fuzz_arbitrary_actions_get_a_defined_answer(
        policy in approval_policy(),
        action in approval_action(),
    ) {
        let is_signing = matches!(action, ApprovalAction::SignWorkflow { .. });

        let answer = needs_approval(policy, &action);

        let asks = policy == ApprovalPolicy::AskBeforeRiskyActions;

        prop_assert_eq!(answer, asks || is_signing);
    }
}
