use orchestration_core::connection_rules::{
    MAXIMUM_CONDITION_LENGTH, ROUND_LIMITS,
};
use orchestration_core::naming::NameProblem;
use orchestration_core::workflow_graph::WorkflowProblem;
use proptest::prelude::*;

use crate::workflow_strategies::agent_identifier;

const ONE_LINE_TEXT: &str = "[a-z0-9 -]{1,12}";

fn list_problems(
    agent_number: u128,
    name: &str,
    condition: &str,
    round_limit: u32,
) -> Vec<WorkflowProblem> {
    let agent_id = agent_identifier(agent_number);
    vec![
        WorkflowProblem::NoAgents,
        WorkflowProblem::DuplicateAgentId { agent_id },
        WorkflowProblem::DuplicateAgentName {
            name: name.to_owned(),
        },
        WorkflowProblem::InvalidStepName {
            name: name.to_owned(),
            problem: NameProblem::Empty,
        },
        WorkflowProblem::UnknownConnectionEnd { agent_id },
        WorkflowProblem::SelfConnection { agent_id },
        WorkflowProblem::RepeatedConnection {
            from: name.to_owned(),
            to: condition.to_owned(),
        },
        WorkflowProblem::Cycle,
        WorkflowProblem::InvalidCondition {
            condition: condition.to_owned(),
        },
        WorkflowProblem::DuplicateCondition {
            step_name: name.to_owned(),
            condition: condition.to_owned(),
        },
        WorkflowProblem::LoopWithoutCondition,
        WorkflowProblem::InvalidRoundLimit { round_limit },
        WorkflowProblem::LoopPointsForward {
            from: name.to_owned(),
            to: condition.to_owned(),
        },
    ]
}

fn list_named_values(problem: &WorkflowProblem) -> Vec<String> {
    match problem {
        WorkflowProblem::NoAgents
        | WorkflowProblem::Cycle
        | WorkflowProblem::LoopWithoutCondition => Vec::new(),
        WorkflowProblem::DuplicateAgentId { agent_id }
        | WorkflowProblem::UnknownConnectionEnd { agent_id }
        | WorkflowProblem::SelfConnection { agent_id } => {
            vec![agent_id.0.to_string()]
        }
        WorkflowProblem::DuplicateAgentName { name } => vec![name.clone()],
        WorkflowProblem::InvalidStepName { name, problem } => {
            vec![format!("{name:?}"), problem.to_string()]
        }
        WorkflowProblem::InvalidCondition { condition } => {
            vec![format!("{condition:?}")]
        }
        WorkflowProblem::DuplicateCondition {
            step_name,
            condition,
        } => vec![step_name.clone(), condition.clone()],
        WorkflowProblem::InvalidRoundLimit { round_limit } => {
            vec![round_limit.to_string()]
        }
        WorkflowProblem::LoopPointsForward { from, to }
        | WorkflowProblem::RepeatedConnection { from, to } => {
            vec![from.clone(), to.clone()]
        }
    }
}

proptest! {
    #[test]
    fn test_workflow_problem_fmt_property_names_every_value_it_carries(
        agent_number in any::<u128>(),
        name in ONE_LINE_TEXT,
        condition in ONE_LINE_TEXT,
        round_limit in any::<u32>(),
    ) {
        let problems =
            list_problems(agent_number, &name, &condition, round_limit);
        for problem in problems {
            let message = problem.to_string();

            for value in list_named_values(&problem) {
                prop_assert!(message.contains(&value), "{message} {value}");
            }
        }
    }

    #[test]
    fn test_workflow_problem_fmt_property_is_one_distinct_line_per_kind(
        agent_number in any::<u128>(),
        name in ONE_LINE_TEXT,
        condition in ONE_LINE_TEXT,
        round_limit in any::<u32>(),
    ) {
        let problems =
            list_problems(agent_number, &name, &condition, round_limit);

        let mut messages: Vec<String> = Vec::new();
        for problem in &problems {
            let message = problem.to_string();
            prop_assert!(!message.trim().is_empty());
            prop_assert!(!message.contains('\n'), "{message}");
            prop_assert!(!messages.contains(&message), "{message}");
            messages.push(message);
        }
    }

    #[test]
    fn test_workflow_problem_fmt_property_limits_match_the_rules(
        condition in ONE_LINE_TEXT,
        round_limit in any::<u32>(),
    ) {
        let condition_message =
            WorkflowProblem::InvalidCondition { condition }.to_string();
        let round_message =
            WorkflowProblem::InvalidRoundLimit { round_limit }.to_string();

        let condition_range = format!("1 to {MAXIMUM_CONDITION_LENGTH}");
        let round_range =
            format!("{} to {}", ROUND_LIMITS.start(), ROUND_LIMITS.end());
        prop_assert!(condition_message.contains(&condition_range));
        prop_assert!(round_message.contains(&round_range));
    }
}
