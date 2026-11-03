use crate::run::{Run, RunStep};
use crate::run_lifecycle::{RunProblem, is_run_finished};

pub fn record_step_result(
    run: &Run,
    step_name: &str,
    result: &str,
    outcome: Option<&str>,
) -> Result<Run, RunProblem> {
    if is_run_finished(run.status) {
        return Err(RunProblem::RunAlreadyFinished);
    }
    let is_known_step = run.steps.iter().any(|step| step.name == step_name);
    if !is_known_step {
        return Err(RunProblem::UnknownStep {
            step_name: step_name.to_owned(),
        });
    }

    let mut recorded_steps = Vec::new();
    for step in &run.steps {
        if step.name == step_name {
            recorded_steps.push(RunStep {
                result: Some(result.to_owned()),
                outcome: outcome.map(str::to_owned),
                ..step.clone()
            });
        } else {
            recorded_steps.push(step.clone());
        }
    }
    Ok(Run {
        steps: recorded_steps,
        ..run.clone()
    })
}
