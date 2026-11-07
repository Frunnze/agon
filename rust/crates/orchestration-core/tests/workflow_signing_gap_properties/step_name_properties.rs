use orchestration_core::naming::validate_name;
use orchestration_core::workflow::{StepKind, Workflow, WorkflowAgent};
use orchestration_core::workflow_graph::{WorkflowProblem, validate_workflow};
use proptest::collection::btree_set;
use proptest::prelude::*;

use crate::routing_fixtures::{connect, routing_agent, routing_workflow};
use crate::workflow_strategies::workflow_from_parts;

const CHAIN_LENGTH: u128 = 3;
const LARGEST_NAMED_STEP_COUNT: usize = 5;
const CHAIN_OUTCOME: &str = "approved";
const RULE_ABIDING_NAME_PATTERN: &str = "[a-z0-9-]{1,40}";
const TOO_LONG_NAME_PATTERN: &str = "[a-z0-9-]{41,48}";
const MIXED_NAME_PATTERN: &str = "[A-Za-z0-9 _.-]{0,12}";
const PRINTABLE_NAME_PATTERN: &str = "\\PC{0,6}";
const FRESH_NAME: &str = "renamed-step";

fn step_name() -> impl Strategy<Value = String> {
    prop_oneof![
        RULE_ABIDING_NAME_PATTERN,
        TOO_LONG_NAME_PATTERN,
        MIXED_NAME_PATTERN,
        PRINTABLE_NAME_PATTERN,
        any::<String>(),
    ]
}

fn rule_breaking_name() -> impl Strategy<Value = String> {
    step_name().prop_filter("a name the rule refuses", |name| {
        validate_name(name).is_err()
    })
}

fn step_kind(is_person: bool) -> StepKind {
    if is_person {
        StepKind::Person
    } else {
        StepKind::Agent
    }
}

fn chain_with_step_named(
    position: prop::sample::Index,
    name: &str,
    is_person: bool,
) -> Workflow {
    let chain = routing_workflow(
        CHAIN_LENGTH,
        vec![
            connect(0, 1, None, None),
            connect(1, 2, Some(CHAIN_OUTCOME), None),
        ],
    );
    let mut agents = chain.agents.clone();
    let renamed_position = position.index(agents.len());
    agents[renamed_position] = WorkflowAgent {
        name: name.to_owned(),
        step_kind: step_kind(is_person),
        ..agents[renamed_position].clone()
    };
    Workflow { agents, ..chain }
}

fn has_shared_name(workflow: &Workflow, name: &str) -> bool {
    let holder_count = workflow
        .agents
        .iter()
        .filter(|agent| agent.name == name)
        .count();
    holder_count > 1
}

fn distinct_step_names() -> impl Strategy<Value = Vec<String>> {
    btree_set(step_name(), 1..=LARGEST_NAMED_STEP_COUNT)
        .prop_map(|names| names.into_iter().collect::<Vec<String>>())
        .prop_shuffle()
}

proptest! {
    #[test]
    fn test_validate_step_names_property_agrees_with_validate_name(
        name in step_name(),
        position in any::<prop::sample::Index>(),
        is_person in any::<bool>(),
    ) {
        let workflow = chain_with_step_named(position, &name, is_person);
        prop_assume!(!has_shared_name(&workflow, &name));

        let verdict = validate_workflow(&workflow);

        let expected = validate_name(&name).map_err(|problem| {
            WorkflowProblem::InvalidStepName {
                name: name.clone(),
                problem,
            }
        });
        prop_assert_eq!(verdict, expected);
    }

    #[test]
    fn test_validate_step_names_property_reports_a_step_breaking_the_rule(
        names in distinct_step_names(),
    ) {
        let mut agents = Vec::new();
        for (number, name) in (0_u128..).zip(&names) {
            agents.push(WorkflowAgent {
                name: name.clone(),
                ..routing_agent(number, StepKind::Agent)
            });
        }
        let workflow = workflow_from_parts(agents, Vec::new());

        let verdict = validate_workflow(&workflow);

        let breaking_names: Vec<&String> = names
            .iter()
            .filter(|name| validate_name(name).is_err())
            .collect();
        match verdict {
            Ok(()) => prop_assert!(breaking_names.is_empty()),
            Err(WorkflowProblem::InvalidStepName { name, problem }) => {
                prop_assert!(breaking_names.contains(&&name));
                prop_assert_eq!(validate_name(&name), Err(problem));
            }
            Err(other) => prop_assert!(false, "unexpected problem {other}"),
        }
    }

    #[test]
    fn test_validate_step_names_property_renaming_the_step_fixes_it(
        name in rule_breaking_name(),
        position in any::<prop::sample::Index>(),
        is_person in any::<bool>(),
    ) {
        let broken = chain_with_step_named(position, &name, is_person);
        let renamed = chain_with_step_named(position, FRESH_NAME, is_person);

        let broken_verdict = validate_workflow(&broken);
        let renamed_verdict = validate_workflow(&renamed);

        let is_name_problem = matches!(
            broken_verdict,
            Err(WorkflowProblem::InvalidStepName { .. })
        );
        prop_assert!(is_name_problem, "{:?}", broken_verdict);
        prop_assert_eq!(renamed_verdict, Ok(()));
    }
}
