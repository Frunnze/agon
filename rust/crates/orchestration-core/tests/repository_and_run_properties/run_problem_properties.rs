use orchestration_core::run_lifecycle::RunProblem;
use orchestration_core::workflow_graph::validate_workflow;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::entity_strategies::{task_with_doer, workflow_doer};
use crate::run_creation_support::{create_test_run, workflow_id_from};
use crate::workflow_strategies::{workflow_identifier, workflow_with_cycle};

const MAXIMUM_CHOICES: usize = 4;
const CHOICE_SEPARATOR: &str = ", ";

proptest! {
    #[test]
    fn test_run_problem_fmt_property_names_the_workflows(
        expected_number in any::<u128>(),
        given_number in any::<u128>(),
    ) {
        let expected = workflow_id_from(expected_number);
        let given = workflow_id_from(given_number);
        let missing = RunProblem::MissingWorkflow { workflow_id: expected };
        let wrong = RunProblem::WrongWorkflow { expected, given };

        let missing_message = missing.to_string();
        let wrong_message = wrong.to_string();

        let expected_text = expected.0.to_string();
        let given_text = given.0.to_string();
        prop_assert!(missing_message.contains(&expected_text));
        let expected_at = wrong_message.find(&expected_text);
        let given_at = wrong_message.rfind(&given_text);
        prop_assert!(expected_at.is_some() && given_at.is_some());
        prop_assert!(expected_at <= given_at);
    }

    #[test]
    fn test_run_problem_fmt_property_lists_every_choice(
        step_name in any::<String>(),
        choices in vec("[a-z][a-z -]{0,8}[a-z]", 1..MAXIMUM_CHOICES),
    ) {
        let unknown_step = RunProblem::UnknownStep {
            step_name: step_name.clone(),
        };
        let unknown_outcome = RunProblem::UnknownOutcome {
            step_name: step_name.clone(),
            choices: choices.clone(),
        };

        let outcome_message = unknown_outcome.to_string();

        prop_assert!(unknown_step.to_string().contains(&step_name));
        prop_assert!(outcome_message.contains(&step_name));
        let listed_choices = choices.join(CHOICE_SEPARATOR);
        prop_assert!(outcome_message.ends_with(&listed_choices));
    }

    #[test]
    fn test_run_problem_fmt_property_workflow_problems_read_unchanged(
        workflow in workflow_with_cycle(),
        task in task_with_doer(workflow_doer(workflow_identifier())),
    ) {
        let workflow_problem = validate_workflow(&workflow).err();

        let run_problem =
            create_test_run(&task, Some(&workflow), task.created_at)
            .err();

        let run_message = run_problem.as_ref().map(ToString::to_string);
        let workflow_message =
            workflow_problem.as_ref().map(ToString::to_string);
        prop_assert!(workflow_message.is_some());
        prop_assert_eq!(run_message, workflow_message);
        prop_assert_eq!(run_problem, workflow_problem.map(RunProblem::from));
    }
}
