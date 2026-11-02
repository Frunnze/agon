use orchestration_core::approval::{ApprovalAction, ApprovalPolicy};
use orchestration_core::workspace::{AgentAccess, Repository};
use orchestration_runner::push_decision::{PushDecision, decide_push};
use proptest::collection::vec;
use proptest::prelude::*;

fn any_policy() -> impl Strategy<Value = ApprovalPolicy> {
    prop_oneof![
        Just(ApprovalPolicy::AskBeforeRiskyActions),
        Just(ApprovalPolicy::NeverAsk),
    ]
}

fn any_access() -> impl Strategy<Value = AgentAccess> {
    prop_oneof![
        Just(AgentAccess::ReadOnly),
        Just(AgentAccess::PushAfterApproval),
    ]
}

proptest! {
    #[test]
    fn test_decide_push_property_pushes_exactly_when_allowed(
        approval_policy in any_policy(),
        agent_access in any_access(),
        commits in vec("[a-zA-Z ]{1,20}", 0..4),
        branch in "task/[a-z]{1,10}",
    ) {
        let repository = Repository {
            address: "github.com/acme/app".to_string(),
            default_branch: "main".to_string(),
            agent_access,
        };

        let decision =
            decide_push(approval_policy, &repository, &branch, &commits);

        let may_push = !commits.is_empty()
            && agent_access == AgentAccess::PushAfterApproval;
        let must_ask = may_push
            && approval_policy == ApprovalPolicy::AskBeforeRiskyActions;
        let expected = if must_ask {
            PushDecision::AskFirst(ApprovalAction::PushCommits {
                repository: repository.address.clone(),
                branch: branch.clone(),
                commits: commits.clone(),
            })
        } else if may_push {
            PushDecision::PushNow
        } else {
            PushDecision::KeepLocal
        };
        prop_assert_eq!(decision, expected);
    }
}
