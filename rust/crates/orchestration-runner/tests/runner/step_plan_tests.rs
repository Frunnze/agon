use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::identifiers::{SkillId, WorkflowId};
use orchestration_core::task::{Task, TaskDoer};
use orchestration_core::workflow::AgentConnection;
use orchestration_runner::step_plan::{AssignmentProblem, plan_assigned_step};
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::assignments::{
    any_agent_kind, assignment_for, claude_task, task_for,
};
use crate::loop_runs::{
    DRAFT_INDEX, SHIP_INDEX, STEP_COUNT, gate_loop_assignment,
};
use crate::support::to_case_error;
use crate::workflows::{
    WORKFLOW_NUMBER, agent_id, agent_name, any_workflow_shape, build_workflow,
};

const TASK_NUMBER: u128 = 0x0101;
const SECOND_LOOP_OUTCOME: &str = "redo";

fn workflow_task() -> Task {
    let doer = TaskDoer::Workflow {
        workflow_id: WorkflowId(Uuid::from_u128(WORKFLOW_NUMBER)),
    };
    task_for(TASK_NUMBER, "Release the app", doer)
}

fn any_policy() -> impl Strategy<Value = ApprovalPolicy> {
    prop_oneof![
        Just(ApprovalPolicy::AskBeforeRiskyActions),
        Just(ApprovalPolicy::NeverAsk),
    ]
}

proptest! {
    #[test]
    fn test_plan_assigned_step_property_plans_exactly_the_given_step(
        shape in any_workflow_shape(),
        chosen in any::<prop::sample::Index>(),
    ) {
        let workflow = build_workflow(&shape);
        let mut assignment = assignment_for(
            workflow_task(), Some(workflow), Vec::new(), TASK_NUMBER,
        ).map_err(to_case_error)?;
        let chosen_index = chosen.index(shape.agent_count);
        assignment.step_name = agent_name(chosen_index);

        let step = plan_assigned_step(&assignment).map_err(to_case_error)?;

        prop_assert_eq!(&step.name, &assignment.step_name);
        prop_assert!(step.instruction.starts_with(&assignment.step_name));
        let mut expected: Vec<String> = shape
            .connections
            .iter()
            .filter(|(_from, to)| *to == chosen_index)
            .map(|(from, _to)| agent_name(*from))
            .collect();
        let mut upstream = step.upstream_step_names.clone();
        expected.sort();
        upstream.sort();
        prop_assert_eq!(upstream, expected);
        prop_assert_eq!(step.loop_round_limit, None);
    }

    #[test]
    fn test_plan_assigned_step_property_knows_the_limit_of_a_lone_loop(
        round_limit in 1_u32..=10,
        chosen_index in 0..STEP_COUNT,
        has_second_loop in any::<bool>(),
    ) {
        let mut assignment =
            gate_loop_assignment(round_limit).map_err(to_case_error)?;
        if let (true, Some(workflow)) =
            (has_second_loop, assignment.workflow.as_mut())
        {
            workflow.connections.push(AgentConnection {
                condition: Some(SECOND_LOOP_OUTCOME.to_owned()),
                round_limit: Some(1),
                ..AgentConnection::plain(
                    agent_id(SHIP_INDEX),
                    agent_id(DRAFT_INDEX),
                )
            });
        }
        assignment.step_name = agent_name(chosen_index);

        let step = plan_assigned_step(&assignment).map_err(to_case_error)?;

        let expected = (!has_second_loop).then_some(round_limit);
        prop_assert_eq!(step.loop_round_limit, expected);
    }

    #[test]
    fn test_plan_assigned_step_property_rejects_steps_outside_the_workflow(
        shape in any_workflow_shape(),
        unknown_name in "unknown-[a-z]{1,8}",
    ) {
        let workflow = build_workflow(&shape);
        let mut assignment = assignment_for(
            workflow_task(), Some(workflow), Vec::new(), TASK_NUMBER,
        ).map_err(to_case_error)?;
        assignment.step_name = unknown_name.clone();

        let planned = plan_assigned_step(&assignment);

        let expected = AssignmentProblem::UnknownStep(unknown_name);
        prop_assert_eq!(planned, Err(expected));
    }

    #[test]
    fn test_plan_assigned_step_property_gives_a_one_agent_task_its_step(
        title in "[a-zA-Z ]{1,30}",
        agent in any_agent_kind(),
        approval_policy in any_policy(),
        skill_numbers in vec(any::<u128>(), 0..3),
        uses_automatic_skills in any::<bool>(),
    ) {
        let skills: Vec<SkillId> = skill_numbers
            .iter()
            .map(|number| SkillId(Uuid::from_u128(*number)))
            .collect();
        let task = Task {
            approval_policy: Some(approval_policy),
            uses_automatic_skills,
            skills: skills.clone(),
            ..task_for(TASK_NUMBER, &title, TaskDoer::OneAgent { agent })
        };
        let assignment = assignment_for(task, None, Vec::new(), TASK_NUMBER)
            .map_err(to_case_error)?;

        let step = plan_assigned_step(&assignment).map_err(to_case_error)?;

        prop_assert_eq!(&step.name, &assignment.run.steps[0].name);
        prop_assert_eq!(step.agent, agent);
        prop_assert_eq!(&step.instruction, &title);
        prop_assert_eq!(&step.pinned_skills, &skills);
        prop_assert_eq!(step.uses_automatic_skills, uses_automatic_skills);
        prop_assert_eq!(step.approval_policy, approval_policy);
        prop_assert!(step.upstream_step_names.is_empty());
    }

    #[test]
    fn test_plan_assigned_step_property_one_agent_names_must_match(
        title in "[a-zA-Z ]{1,30}",
        unknown_name in "unknown-[a-z]{1,8}",
    ) {
        let task = claude_task(TASK_NUMBER, &title);
        let mut assignment =
            assignment_for(task, None, Vec::new(), TASK_NUMBER)
                .map_err(to_case_error)?;
        assignment.step_name = unknown_name.clone();

        let planned = plan_assigned_step(&assignment);

        let expected = AssignmentProblem::UnknownStep(unknown_name);
        prop_assert_eq!(planned, Err(expected));
    }

    #[test]
    fn test_plan_assigned_step_property_rejects_mismatched_assignments(
        shape in any_workflow_shape(),
        mismatch in 0_usize..4,
    ) {
        let workflow = build_workflow(&shape);
        let mut assignment = assignment_for(
            workflow_task(), Some(workflow.clone()), Vec::new(), TASK_NUMBER,
        ).map_err(to_case_error)?;
        assignment.step_name = agent_name(0);
        let expected_problem = match mismatch {
            0 => {
                assignment.workflow = None;
                AssignmentProblem::MissingWorkflow
            }
            1 => {
                assignment.task = claude_task(TASK_NUMBER, "Fix it");
                AssignmentProblem::UnexpectedWorkflow
            }
            2 => {
                let mut changed = workflow;
                changed.id = WorkflowId(Uuid::from_u128(TASK_NUMBER));
                assignment.workflow = Some(changed);
                let expected_id = WorkflowId(Uuid::from_u128(WORKFLOW_NUMBER));
                AssignmentProblem::WrongWorkflow(expected_id)
            }
            _ => {
                let mut changed = workflow;
                changed.agents[0].kind = None;
                let name = changed.agents[0].name.clone();
                assignment.workflow = Some(changed);
                AssignmentProblem::MissingAgentKind(name)
            }
        };

        let planned = plan_assigned_step(&assignment);
        prop_assert_eq!(planned, Err(expected_problem));
    }
}
