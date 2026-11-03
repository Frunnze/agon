use chrono::DateTime;
use orchestration_core::run::{RunStatus, StepStatus};
use orchestration_core::run_routing::{
    is_step_claimable, settle_waiting_steps,
};
use orchestration_core::workflow::{StepKind, Workflow, WorkflowAgent};
use proptest::prelude::*;

use crate::routing_fixtures::{
    connect, finish_step, fresh_run, routing_agent, routing_workflow,
    step_named,
};
use crate::workflow_strategies::workflow_from_parts;

const SOURCE: u128 = 0;
const MOST_BRANCHES: u128 = 5;

fn fork_workflow(branch_count: u128, plain_count: u128) -> Workflow {
    let mut connections = Vec::new();
    for branch in 1..=branch_count {
        let condition = format!("outcome {branch}");
        connections.push(connect(SOURCE, branch, Some(&condition), None));
    }
    let first_plain = branch_count + 1;
    for plain in first_plain..first_plain + plain_count {
        connections.push(connect(SOURCE, plain, None, None));
    }
    routing_workflow(first_plain + plain_count, connections)
}

fn join_workflow() -> Workflow {
    routing_workflow(
        4,
        vec![
            connect(0, 1, Some("left"), None),
            connect(0, 2, Some("right"), None),
            connect(1, 3, None, None),
            connect(2, 3, None, None),
        ],
    )
}

fn loop_workflow(round_limit: u32) -> Workflow {
    routing_workflow(
        3,
        vec![
            connect(0, 1, None, None),
            connect(1, 2, None, None),
            connect(2, 0, Some("again"), Some(round_limit)),
        ],
    )
}

proptest! {
    #[test]
    fn test_advance_after_step_property_takes_only_the_matching_branch(
        branch_count in 1..=MOST_BRANCHES,
        plain_count in 0..=2_u128,
        chosen in any::<prop::sample::Index>(),
    ) {
        let workflow = fork_workflow(branch_count, plain_count);
        let chosen_branch = 1 + chosen.index(usize::try_from(branch_count)?);
        let outcome = format!("outcome {chosen_branch}");

        let fresh = fresh_run(&workflow);
        let run = finish_step(&fresh, &workflow, "step-0", Some(&outcome));

        for (index, step) in run.steps.iter().enumerate().skip(1) {
            let is_plain = index > usize::try_from(branch_count)?;
            let is_taken = is_plain || index == chosen_branch;
            let expected = if is_taken {
                StepStatus::Waiting
            } else {
                StepStatus::Skipped
            };
            prop_assert_eq!(step.status, expected);
            let is_claimable = is_step_claimable(&run, step, Some(&workflow));
            prop_assert_eq!(is_claimable, is_taken);
        }
    }

    #[test]
    fn test_advance_after_step_property_joins_only_the_taken_branches(
        takes_left in any::<bool>(),
    ) {
        let workflow = join_workflow();
        let (taken, skipped) = if takes_left {
            ("step-1", "step-2")
        } else {
            ("step-2", "step-1")
        };
        let outcome = if takes_left { "left" } else { "right" };

        let fresh = fresh_run(&workflow);
        let forked = finish_step(&fresh, &workflow, "step-0", Some(outcome));
        let joined = finish_step(&forked, &workflow, taken, None);

        let join_before = step_named(&forked, "step-3");
        let is_join_claimable =
            is_step_claimable(&forked, join_before, Some(&workflow));
        prop_assert!(!is_join_claimable);
        let skipped_status = step_named(&forked, skipped).status;
        prop_assert_eq!(skipped_status, StepStatus::Skipped);
        let join_after = step_named(&joined, "step-3");
        prop_assert!(is_step_claimable(&joined, join_after, Some(&workflow)));
    }

    #[test]
    fn test_advance_after_step_property_loops_until_the_round_limit(
        round_limit in 1_u32..=10,
    ) {
        let workflow = loop_workflow(round_limit);
        let mut run = fresh_run(&workflow);

        for _round in 0..=round_limit {
            run = finish_step(&run, &workflow, "step-0", None);
            run = finish_step(&run, &workflow, "step-1", None);
            run = finish_step(&run, &workflow, "step-2", Some("again"));
        }

        prop_assert_eq!(run.status, RunStatus::Done);
        prop_assert_eq!(run.loop_rounds.len(), 1);
        prop_assert_eq!(run.loop_rounds[0].rounds, round_limit);
        let first = step_named(&run, "step-0");
        let expected_rounds = usize::try_from(round_limit)?;
        prop_assert_eq!(first.earlier_rounds.len(), expected_rounds);
        let limit_note = format!(
            "step-2 → step-0 reached its limit of {round_limit} rounds"
        );
        let note_texts: Vec<&str> =
            run.notes.iter().map(|note| note.text.as_str()).collect();
        prop_assert_eq!(
            note_texts,
            vec![
                limit_note.as_str(),
                "Nothing else follows step-2, so the run finished",
            ]
        );
    }

    #[test]
    fn test_advance_after_step_property_carries_the_loop_source_in(
        round_limit in 1_u32..=10,
    ) {
        let workflow = loop_workflow(round_limit);
        let mut run = fresh_run(&workflow);
        run = finish_step(&run, &workflow, "step-0", None);
        run = finish_step(&run, &workflow, "step-1", None);

        run = finish_step(&run, &workflow, "step-2", Some("again"));

        let target = step_named(&run, "step-0");
        prop_assert_eq!(target.loop_source.as_deref(), Some("step-2"));
        prop_assert!(is_step_claimable(&run, target, Some(&workflow)));
        let source = step_named(&run, "step-2");
        prop_assert_eq!(source.status, StepStatus::Waiting);
        let earlier_result = source
            .earlier_rounds
            .last()
            .and_then(|round| round.result.as_deref());
        prop_assert_eq!(earlier_result, Some("result of step-2"));
    }

    #[test]
    fn test_settle_waiting_steps_property_never_offers_a_person_step(
        has_upstream in any::<bool>(),
    ) {
        let person = WorkflowAgent {
            ..routing_agent(1, StepKind::Person)
        };
        let agents = vec![routing_agent(0, StepKind::Agent), person];
        let connections = if has_upstream {
            vec![connect(0, 1, None, None)]
        } else {
            Vec::new()
        };
        let workflow = workflow_from_parts(agents, connections);
        let mut run = fresh_run(&workflow);
        if has_upstream {
            run = finish_step(&run, &workflow, "step-0", None);
        }

        let settled =
            settle_waiting_steps(&run, &workflow, DateTime::UNIX_EPOCH);

        let person_step = step_named(&settled, "step-1");
        prop_assert_eq!(person_step.status, StepStatus::WaitingForPerson);
        let is_claimable =
            is_step_claimable(&settled, person_step, Some(&workflow));
        prop_assert!(!is_claimable);
        prop_assert_eq!(settled.status, RunStatus::Running);
    }
}
