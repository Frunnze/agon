use chrono::{DateTime, Utc};
use orchestration_core::run::{Run, RunStatus, StepStatus};
use orchestration_core::run_lifecycle::{
    RunProblem, apply_step_status, is_run_finished,
};
use orchestration_core::run_routing::{
    advance_after_step, advance_newly_done_steps,
};
use orchestration_core::step_results::record_step_result;
use orchestration_core::workflow::Workflow;
use proptest::prelude::*;

use crate::entity_strategies::ordinary_timestamp;
use crate::loop_support::{
    LOOP_OUTCOME, LoopPlan, build_loop_workflow, count_loop_rounds, loop_plan,
    step_name,
};
use crate::routing_fixtures::{finish_step, fresh_run, step_named};

const STOPPED_RUN_STATUSES: [RunStatus; 2] =
    [RunStatus::Failed, RunStatus::Cancelled];

fn last_step_loop_plan() -> impl Strategy<Value = LoopPlan> {
    loop_plan().prop_map(|plan| LoopPlan {
        source: plan.agent_count - 1,
        ..plan
    })
}

fn finish_through_lifecycle(
    run: &Run,
    workflow: &Workflow,
    finished_step: &str,
    outcome: Option<&str>,
    at: DateTime<Utc>,
) -> Result<Run, RunProblem> {
    let result_text = format!("result of {finished_step}");
    let recorded =
        record_step_result(run, finished_step, &result_text, outcome)?;
    let done =
        apply_step_status(&recorded, finished_step, StepStatus::Done, at)?;
    advance_newly_done_steps(&recorded, &done, workflow, at)
}

fn finish_one_pass(
    run: &Run,
    plan: LoopPlan,
    first_step: u128,
    at: DateTime<Utc>,
) -> Result<Run, RunProblem> {
    let workflow = build_loop_workflow(plan);
    let mut advanced = run.clone();
    for number in first_step..plan.source {
        let name = step_name(number);
        advanced =
            finish_through_lifecycle(&advanced, &workflow, &name, None, at)?;
    }
    let source = step_name(plan.source);
    let outcome = Some(LOOP_OUTCOME);
    finish_through_lifecycle(&advanced, &workflow, &source, outcome, at)
}

fn is_target_waiting(run: &Run, plan: LoopPlan) -> bool {
    let target = step_named(run, &step_name(plan.target));
    target.status == StepStatus::Waiting
}

proptest! {
    #[test]
    fn test_advance_after_step_property_a_last_step_loop_reopens_the_run(
        plan in last_step_loop_plan(),
        at in ordinary_timestamp(),
    ) {
        let workflow = build_loop_workflow(plan);

        let looped = finish_one_pass(&fresh_run(&workflow), plan, 0, at);

        let Ok(looped) = looped else {
            return Err(TestCaseError::fail("the pass must finish"));
        };
        prop_assert!(!is_run_finished(looped.status), "{:?}", looped.status);
        prop_assert_eq!(looped.finished_at, None);
        prop_assert!(is_target_waiting(&looped, plan));
        let source = step_name(plan.source);
        let target = step_name(plan.target);
        prop_assert_eq!(count_loop_rounds(&looped, &source, &target), 1);
    }

    #[test]
    fn test_advance_newly_done_steps_property_a_last_step_loop_runs_out(
        plan in last_step_loop_plan(),
        at in ordinary_timestamp(),
    ) {
        let workflow = build_loop_workflow(plan);
        let mut run = fresh_run(&workflow);
        let mut first_step = 0;
        let mut rounds_taken = 0;

        for _ in 0..=plan.round_limit {
            let finished = finish_one_pass(&run, plan, first_step, at);
            let Ok(finished) = finished else {
                return Err(TestCaseError::fail("every pass must finish"));
            };
            run = finished;
            if !is_target_waiting(&run, plan) {
                break;
            }
            rounds_taken += 1;
            first_step = plan.target;
        }

        prop_assert_eq!(rounds_taken, plan.round_limit);
        prop_assert_eq!(run.status, RunStatus::Done);
        prop_assert_eq!(run.finished_at, Some(at));
        let source = step_name(plan.source);
        let ending = format!(
            "Nothing else follows {source}, so the run finished"
        );
        let last_note = run.notes.last().map(|note| note.text.clone());
        prop_assert_eq!(last_note, Some(ending));
    }

    #[test]
    fn test_advance_after_step_property_a_stopped_run_never_loops(
        plan in loop_plan(),
        stopped_status in prop::sample::select(&STOPPED_RUN_STATUSES[..]),
        at in ordinary_timestamp(),
    ) {
        let workflow = build_loop_workflow(plan);
        let mut run = fresh_run(&workflow);
        for number in 0..plan.source {
            run = finish_step(&run, &workflow, &step_name(number), None);
        }
        let source = step_name(plan.source);
        for step in &mut run.steps {
            if step.name == source {
                step.status = StepStatus::Done;
                step.outcome = Some(LOOP_OUTCOME.to_owned());
            }
        }
        let stopped = Run {
            status: stopped_status,
            finished_at: Some(at),
            ..run
        };

        let advanced = advance_after_step(&stopped, &workflow, &source, at);

        prop_assert_eq!(advanced, stopped);
    }
}
