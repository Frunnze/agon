use orchestration_core::workflow::{StepKind, Workflow};
use orchestration_core::workflow_document::render_workflow_document;
use proptest::prelude::*;

use crate::branching_strategies::{branching_plan, build_branching_workflow};
use crate::routing_fixtures::{connect, routing_agent};
use crate::workflow_strategies::workflow_from_parts;

fn review_workflow() -> Workflow {
    let draft = routing_agent(0, StepKind::Agent);
    let approve = orchestration_core::workflow::WorkflowAgent {
        task: "Approve the draft?".to_owned(),
        ..routing_agent(1, StepKind::Person)
    };
    let ship = routing_agent(2, StepKind::Agent);
    workflow_from_parts(
        vec![draft, approve, ship],
        vec![
            connect(0, 1, None, None),
            connect(1, 2, Some("approved"), None),
            connect(1, 0, Some("changes"), Some(3)),
        ],
    )
}

#[test]
fn test_render_workflow_document_writes_person_steps_and_outcomes() {
    let document = render_workflow_document(&review_workflow());

    let expected_approve = "  - name: step-1\n    \
        kind: person\n    \
        after: [step-0]\n    \
        question: \"Approve the draft?\"\n    \
        outcomes: [\"approved -> step-2\", \
        \"changes -> step-0, at most 3 rounds\"]\n";
    assert!(document.contains(expected_approve), "{document}");
    assert!(!document.contains("step-0, at most 3 rounds\"]\n    agent"));
}

proptest! {
    #[test]
    fn test_render_workflow_document_property_covers_outcomes_and_kinds(
        plan in branching_plan(),
        chosen in any::<prop::sample::Index>(),
    ) {
        let workflow = build_branching_workflow(&plan);
        let index = chosen.index(workflow.connections.len().max(1));
        prop_assume!(index < workflow.connections.len());
        let mut renamed = workflow.clone();
        renamed.connections[index].condition = Some("renamed".to_owned());
        let mut relimited = workflow.clone();
        let changed_limit = workflow.connections[index]
            .round_limit
            .map_or(Some(1), |limit| Some(limit % 10 + 1));
        relimited.connections[index].round_limit = changed_limit;
        relimited.connections[index].condition =
            Some("limited".to_owned());
        let mut rekinded = workflow.clone();
        let flipped_kind = match rekinded.agents[0].step_kind {
            StepKind::Agent => StepKind::Person,
            StepKind::Person => StepKind::Agent,
        };
        rekinded.agents[0].step_kind = flipped_kind;

        let original = render_workflow_document(&workflow);

        prop_assert_ne!(&original, &render_workflow_document(&renamed));
        prop_assert_ne!(&original, &render_workflow_document(&relimited));
        prop_assert_ne!(&original, &render_workflow_document(&rekinded));
    }
}
