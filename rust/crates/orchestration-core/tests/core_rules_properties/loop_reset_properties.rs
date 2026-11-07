use chrono::DateTime;
use orchestration_core::identifiers::DeviceId;
use orchestration_core::run::{LoopRounds, Run, RunStep, StepStatus};
use proptest::collection::{btree_set, vec};
use proptest::prelude::*;

use crate::loop_support::{
    LOOP_OUTCOME, LoopPlan, build_loop_workflow, count_loop_rounds,
    finish_round, loop_plan, name_in_run,
};
use crate::routing_fixtures::{finish_step, fresh_run};
use crate::workflow_strategies::agent_identifier;

const RUNNER: &str = "runner-1";
const MAXIMUM_ROUNDS: u32 = 3;

fn step_number(step: &RunStep) -> Option<u128> {
    step.agent_id.map(|agent_id| agent_id.0.as_u128())
}

fn is_in_loop_region(step: &RunStep, plan: LoopPlan) -> bool {
    step_number(step).is_some_and(|number| number >= plan.target)
}

fn run_up_to_the_source(plan: LoopPlan) -> Run {
    let workflow = build_loop_workflow(plan);
    let mut run = fresh_run(&workflow);
    for number in 0..plan.source {
        let name = name_in_run(&run, number).unwrap_or_default();
        run = finish_step(&run, &workflow, &name, None);
    }
    for step in &mut run.steps {
        if step.status == StepStatus::Done {
            step.runner = Some(DeviceId(RUNNER.to_owned()));
            step.started_at = Some(DateTime::UNIX_EPOCH);
            step.finished_at = Some(DateTime::UNIX_EPOCH);
        }
    }
    run
}

fn take_the_loop(plan: LoopPlan, run: &Run) -> Run {
    let workflow = build_loop_workflow(plan);
    let source = name_in_run(run, plan.source).unwrap_or_default();
    finish_step(run, &workflow, &source, Some(LOOP_OUTCOME))
}

fn renamed_steps(run: &Run, names: &[String]) -> Run {
    let mut steps = Vec::new();
    for (step, name) in run.steps.iter().zip(names) {
        steps.push(RunStep {
            name: name.clone(),
            ..step.clone()
        });
    }
    Run {
        steps,
        ..run.clone()
    }
}

fn step_names() -> impl Strategy<Value = Vec<String>> {
    btree_set("[A-Za-z][A-Za-z0-9 _.-]{0,8}", 6)
        .prop_map(|names| names.into_iter().collect())
}

proptest! {
    #[test]
    fn test_start_loop_round_property_resets_only_the_loop_region(
        plan in loop_plan(),
    ) {
        let before = run_up_to_the_source(plan);

        let after = take_the_loop(plan, &before);

        for step in &after.steps {
            if is_in_loop_region(step, plan) {
                prop_assert_eq!(step.status, StepStatus::Waiting);
            } else {
                prop_assert_eq!(step.status, StepStatus::Done);
                prop_assert!(step.earlier_rounds.is_empty());
            }
        }
    }

    #[test]
    fn test_start_loop_round_property_keeps_the_rest_of_the_run(
        plan in loop_plan(),
    ) {
        let before = run_up_to_the_source(plan);

        let after = take_the_loop(plan, &before);

        prop_assert_eq!(after.id, before.id);
        prop_assert_eq!(after.task_id, before.task_id);
        prop_assert_eq!(after.number, before.number);
        prop_assert_eq!(after.started_by, before.started_by);
        prop_assert_eq!(after.started_at, before.started_at);
        prop_assert_eq!(after.log, before.log);
        prop_assert_eq!(after.notes, before.notes);
        prop_assert_eq!(after.steps.len(), before.steps.len());
    }

    #[test]
    fn test_start_loop_round_property_archives_each_round_once(
        plan in loop_plan(),
        rounds_to_take in 1..=MAXIMUM_ROUNDS,
    ) {
        let workflow = build_loop_workflow(plan);
        let rounds_to_take = rounds_to_take.min(plan.round_limit);
        let mut run = finish_round(&fresh_run(&workflow), &workflow, plan, 0);
        let mut rounds_taken: usize = 1;
        for _ in 1..rounds_to_take {
            run = finish_round(&run, &workflow, plan, plan.target);
            rounds_taken += 1;
        }

        for step in &run.steps {
            let Some(number) = step_number(step) else {
                continue;
            };
            if (plan.target..=plan.source).contains(&number) {
                prop_assert_eq!(step.earlier_rounds.len(), rounds_taken);
            }
            if number == plan.source {
                for earlier in &step.earlier_rounds {
                    prop_assert_eq!(earlier.status, StepStatus::Done);
                    prop_assert_eq!(
                        earlier.outcome.as_deref(),
                        Some(LOOP_OUTCOME)
                    );
                }
            }
        }
    }

    #[test]
    fn test_reset_for_round_property_leaves_busy_steps_alone(
        plan in loop_plan(),
        busy_marks in vec(any::<bool>(), 6),
        is_waiting_for_approval in any::<bool>(),
    ) {
        let mut before = run_up_to_the_source(plan);
        let busy_status = if is_waiting_for_approval {
            StepStatus::WaitingForApproval
        } else {
            StepStatus::Running
        };
        for (step, is_busy) in before.steps.iter_mut().zip(&busy_marks) {
            let is_source = step_number(step) == Some(plan.source);
            if *is_busy && !is_source {
                step.status = busy_status;
                step.runner = Some(DeviceId(RUNNER.to_owned()));
            }
        }

        let after = take_the_loop(plan, &before);

        for (old_step, new_step) in before.steps.iter().zip(&after.steps) {
            if old_step.status == busy_status {
                prop_assert_eq!(new_step, old_step);
            }
        }
    }

    #[test]
    fn test_reset_for_round_property_clears_what_the_round_left(
        plan in loop_plan(),
    ) {
        let before = run_up_to_the_source(plan);

        let after = take_the_loop(plan, &before);

        for step in after.steps.iter().filter(|step| {
            is_in_loop_region(step, plan)
        }) {
            prop_assert_eq!(step.runner.as_ref(), None);
            prop_assert_eq!(step.started_at, None);
            prop_assert_eq!(step.finished_at, None);
            prop_assert_eq!(step.result.as_ref(), None);
            prop_assert_eq!(step.outcome.as_ref(), None);
        }
    }

    #[test]
    fn test_reset_for_round_property_only_the_target_shows_the_source(
        plan in loop_plan(),
    ) {
        let before = run_up_to_the_source(plan);
        let source = name_in_run(&before, plan.source).unwrap_or_default();

        let after = take_the_loop(plan, &before);

        for step in &after.steps {
            let is_target = step_number(step) == Some(plan.target);
            let expected_source = is_target.then(|| source.clone());
            prop_assert_eq!(step.loop_source.clone(), expected_source);
        }
    }

    #[test]
    fn test_name_step_of_property_keys_rounds_by_the_run_step_names(
        plan in loop_plan(),
        names in step_names(),
    ) {
        let workflow = build_loop_workflow(plan);
        let renamed = renamed_steps(&fresh_run(&workflow), &names);
        let source = name_in_run(&renamed, plan.source).unwrap_or_default();
        let target = name_in_run(&renamed, plan.target).unwrap_or_default();

        let run = finish_round(&renamed, &workflow, plan, 0);

        prop_assert_eq!(run.loop_rounds, vec![LoopRounds {
            from: source,
            to: target,
            rounds: 1,
        }]);
    }

    #[test]
    fn test_name_step_of_property_the_limit_note_names_both_steps(
        plan in loop_plan(),
        names in step_names(),
    ) {
        let workflow = build_loop_workflow(plan);
        let renamed = renamed_steps(&fresh_run(&workflow), &names);
        let source = name_in_run(&renamed, plan.source).unwrap_or_default();
        let target = name_in_run(&renamed, plan.target).unwrap_or_default();
        let at_limit = Run {
            loop_rounds: vec![LoopRounds {
                from: source.clone(),
                to: target.clone(),
                rounds: plan.round_limit,
            }],
            ..renamed
        };

        let run = finish_round(&at_limit, &workflow, plan, 0);

        let limit_note = run.notes.first().map(|note| note.text.clone());
        let expected_start = format!("{source} → {target} ");
        let names_both_steps = limit_note.is_some_and(|text| {
            text.starts_with(&expected_start)
                && text.contains(&plan.round_limit.to_string())
        });
        prop_assert!(names_both_steps);
    }

    #[test]
    fn test_name_step_of_property_a_missing_target_still_stops_looping(
        plan in loop_plan(),
    ) {
        let workflow = build_loop_workflow(plan);
        let target_id = agent_identifier(plan.target);
        let mut run = fresh_run(&workflow);
        run.steps.retain(|step| step.agent_id != Some(target_id));
        let target_text = target_id.0.to_string();
        let source = name_in_run(&run, plan.source).unwrap_or_default();

        run = finish_round(&run, &workflow, plan, 0);
        for _ in 0..=plan.round_limit {
            run = finish_round(&run, &workflow, plan, plan.target);
        }

        prop_assert_eq!(
            count_loop_rounds(&run, &source, &target_text),
            plan.round_limit
        );
    }
}
