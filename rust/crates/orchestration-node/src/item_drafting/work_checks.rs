use chrono::Utc;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{ProjectId, SkillId};
use orchestration_core::schedule_rules::next_run_after;
use orchestration_core::task::{Schedule, TaskDoer};

use super::draft_checks::CheckedDraft;
use super::drafting_context::DraftingContext;
use super::item_draft::{ItemDraft, WorkDraft};
use super::problem_sentences::{
    EMPTY_WORK_TITLE, JOB_WITHOUT_SCHEDULE, describe_foreign_project,
    describe_foreign_runner, describe_invalid_schedule,
    describe_missing_project, describe_unknown_skill,
    describe_unknown_workflow, describe_unsigned_workflow,
};

pub(super) fn check_task_draft(
    context: &DraftingContext,
    work: &WorkDraft,
) -> CheckedDraft {
    let completed = complete_work(context, work);
    let problems = find_work_problems(context, &completed);
    CheckedDraft {
        draft: ItemDraft::Task(completed),
        problems,
    }
}

pub(super) fn check_job_draft(
    context: &DraftingContext,
    work: &WorkDraft,
) -> CheckedDraft {
    let completed = complete_work(context, work);
    let mut problems = find_work_problems(context, &completed);
    if completed.schedule.is_none() {
        problems.push(JOB_WITHOUT_SCHEDULE.to_owned());
    }
    CheckedDraft {
        draft: ItemDraft::Job(completed),
        problems,
    }
}

fn complete_work(context: &DraftingContext, work: &WorkDraft) -> WorkDraft {
    let trimmed = work.trimmed();
    let project_id = trimmed
        .project_id
        .or_else(|| context.find_only_project_id());
    WorkDraft {
        project_id,
        ..trimmed
    }
}

fn find_work_problems(
    context: &DraftingContext,
    work: &WorkDraft,
) -> Vec<String> {
    let title_problem =
        work.title.is_empty().then(|| EMPTY_WORK_TITLE.to_owned());
    let possible_problems = [
        title_problem,
        find_project_problem(context, work.project_id),
        find_doer_problem(context, &work.doer),
        find_runner_problem(context, &work.runs_on),
        find_skill_problem(context, &work.skills),
        find_schedule_problem(work.schedule.as_ref()),
    ];
    possible_problems.into_iter().flatten().collect()
}

fn find_project_problem(
    context: &DraftingContext,
    project_id: Option<ProjectId>,
) -> Option<String> {
    let workspace_name = &context.workspace.name;
    let project_names = context.list_project_names();
    let Some(project_id) = project_id else {
        return Some(describe_missing_project(workspace_name, &project_names));
    };
    if context.includes_project(project_id) {
        return None;
    }
    Some(describe_foreign_project(workspace_name, &project_names))
}

fn find_doer_problem(
    context: &DraftingContext,
    doer: &TaskDoer,
) -> Option<String> {
    let TaskDoer::Workflow { workflow_id } = doer else {
        return None;
    };
    let workflow = context
        .workflows
        .iter()
        .find(|workflow| workflow.id == *workflow_id);
    let signed_names = context.list_signed_workflow_names();
    let Some(workflow) = workflow else {
        return Some(describe_unknown_workflow(&signed_names));
    };
    if workflow.is_signed {
        return None;
    }
    Some(describe_unsigned_workflow(&workflow.name, &signed_names))
}

fn find_runner_problem(
    context: &DraftingContext,
    runs_on: &RunnerTarget,
) -> Option<String> {
    let RunnerTarget::SpecificRunner { device_id } = runs_on else {
        return None;
    };
    let is_listed = context
        .runners
        .iter()
        .any(|runner| runner.device.id == *device_id);
    if is_listed {
        return None;
    }
    let runner_names = context.list_runner_names();
    Some(describe_foreign_runner(
        &context.workspace.name,
        &runner_names,
    ))
}

fn find_skill_problem(
    context: &DraftingContext,
    skills: &[SkillId],
) -> Option<String> {
    let has_unknown_skill = skills.iter().any(|skill_id| {
        !context.skills.iter().any(|skill| skill.id == *skill_id)
    });
    if !has_unknown_skill {
        return None;
    }
    Some(describe_unknown_skill(&context.list_skill_names()))
}

fn find_schedule_problem(schedule: Option<&Schedule>) -> Option<String> {
    let schedule = schedule?;
    let problem = next_run_after(schedule, Utc::now()).err()?;
    Some(describe_invalid_schedule(&problem))
}
