use orchestration_api::work::RunAssignment;
use orchestration_core::library::Skill;
use orchestration_core::run::{Run, RunStep};

use crate::earlier_rounds_prompt::describe_earlier_rounds;
use crate::step_outcome::compose_outcome_request;
use crate::step_plan::StepPlan;
use crate::step_prompt::{UpstreamResult, compose_step_prompt};

const SECTION_SEPARATOR: &str = "\n\n";

#[must_use]
pub fn compose_assignment_prompt(
    step: &StepPlan,
    assignment: &RunAssignment,
    repository_folders: &[String],
    skills: &[&Skill],
) -> String {
    let run = &assignment.run;
    let upstream_results = collect_upstream_results(step, run);
    let mut sections = vec![compose_step_prompt(
        &step.instruction,
        &assignment.task.details,
        repository_folders,
        skills,
        &upstream_results,
    )];
    if let Some(earlier_rounds) = describe_own_earlier_rounds(step, run) {
        sections.push(earlier_rounds);
    }
    if !step.outcome_choices.is_empty() {
        sections.push(compose_outcome_request(&step.outcome_choices));
    }
    sections.join(SECTION_SEPARATOR)
}

fn describe_own_earlier_rounds(step: &StepPlan, run: &Run) -> Option<String> {
    let own_step = find_run_step(run, &step.name)?;
    describe_earlier_rounds(&own_step.earlier_rounds, step.loop_round_limit)
}

fn find_run_step<'run>(
    run: &'run Run,
    step_name: &str,
) -> Option<&'run RunStep> {
    run.steps.iter().find(|run_step| run_step.name == step_name)
}

fn collect_upstream_results(
    step: &StepPlan,
    run: &Run,
) -> Vec<UpstreamResult> {
    let mut upstream_results = Vec::new();
    for run_step in &run.steps {
        let is_upstream = step.upstream_step_names.contains(&run_step.name);
        if let (true, Some(result)) = (is_upstream, &run_step.result) {
            upstream_results.push(UpstreamResult {
                step_name: run_step.name.clone(),
                final_message: result.clone(),
            });
        }
    }
    if let Some(looped_result) = find_looped_result(step, run) {
        upstream_results.push(looped_result);
    }
    upstream_results
}

fn find_looped_result(step: &StepPlan, run: &Run) -> Option<UpstreamResult> {
    let own_step = find_run_step(run, &step.name);
    let loop_source = own_step?.loop_source.as_ref()?;
    let source_step = find_run_step(run, loop_source)?;
    let last_round = source_step.earlier_rounds.last()?;
    let final_message = last_round.result.clone()?;
    Some(UpstreamResult {
        step_name: loop_source.clone(),
        final_message,
    })
}
