use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{
    DeviceId, ProjectId, SkillId, WorkflowId,
};
use orchestration_core::task::{Schedule, TaskDoer};
use orchestration_node::item_drafting::{
    DraftingContext, DraftingWorkflow, ItemDraft, WorkDraft, check_item_draft,
};
use proptest::prelude::*;
use uuid::Uuid;

use crate::support::draft_problem_texts::{
    join_choices, join_names, list_project_names, list_runner_names,
    list_signed_workflow_names, list_skill_names,
};
use crate::support::drafting_samples::{
    FOREIGN_DEVICE_ID, context_strategy, foreign_uuid, padded, sample_project,
    valid_work_draft,
};
use crate::support::entity_strategies::secret_text_strategy;

const CHECK_CASES: u32 = 32;
const UNSIGNED_WORKFLOW_NAME: &str = "unsigned-flow";
const INVALID_MINUTE: u32 = 75;
const PROJECT_IDENTIFIER_BASE: u128 = 0x100;
const JOB_WITHOUT_SCHEDULE: &str = "Repeats: a job needs a schedule. Ask \
                                    for changes and say how often it \
                                    repeats.";
const EXTRA_PROJECT_INDEX: usize = 7;

type WorkWrapper = fn(WorkDraft) -> ItemDraft;

#[derive(Clone, Copy, Debug)]
enum WorkDefect {
    EmptyTitle,
    NoProject,
    ForeignProject,
    UnknownWorkflow,
    UnsignedWorkflow,
    ForeignRunner,
    UnknownSkill,
    InvalidSchedule,
}

fn work_defect_strategy() -> impl Strategy<Value = WorkDefect> {
    prop_oneof![
        Just(WorkDefect::EmptyTitle),
        Just(WorkDefect::NoProject),
        Just(WorkDefect::ForeignProject),
        Just(WorkDefect::UnknownWorkflow),
        Just(WorkDefect::UnsignedWorkflow),
        Just(WorkDefect::ForeignRunner),
        Just(WorkDefect::UnknownSkill),
        Just(WorkDefect::InvalidSchedule),
    ]
}

fn work_wrapper_strategy() -> impl Strategy<Value = WorkWrapper> {
    let task: WorkWrapper = ItemDraft::Task;
    let job: WorkWrapper = ItemDraft::Job;
    prop_oneof![Just(task), Just(job)]
}

fn describe_workflow_choices(context: &DraftingContext) -> String {
    join_choices(list_signed_workflow_names(context), "one agent")
}

fn apply_work_defect(
    context: &mut DraftingContext,
    work: &mut WorkDraft,
    defect: WorkDefect,
) -> String {
    match defect {
        WorkDefect::EmptyTitle => {
            " \n ".clone_into(&mut work.title);
            "What should be done: it is empty. Ask for changes and say what \
             should be done."
                .to_owned()
        }
        WorkDefect::NoProject => {
            let extra =
                sample_project(EXTRA_PROJECT_INDEX, "extra", "github.com/a/x");
            context.projects.push(extra);
            work.project_id = None;
            format!(
                "Project: the agent could not tell which one. Ask for \
                 changes and name one of: {}.",
                join_names(&list_project_names(context))
            )
        }
        WorkDefect::ForeignProject => {
            work.project_id = Some(ProjectId(foreign_uuid()));
            format!(
                "Project: the chosen one is not in acme. Ask for changes and \
                 name one of: {}.",
                join_names(&list_project_names(context))
            )
        }
        WorkDefect::UnknownWorkflow => {
            work.doer = TaskDoer::Workflow {
                workflow_id: WorkflowId(foreign_uuid()),
            };
            format!(
                "Who does it: the chosen workflow does not exist here. Ask \
                 for changes and name one of: {}.",
                describe_workflow_choices(context)
            )
        }
        WorkDefect::UnsignedWorkflow => {
            let workflow_id = WorkflowId(foreign_uuid());
            context.workflows.push(DraftingWorkflow {
                id: workflow_id,
                name: UNSIGNED_WORKFLOW_NAME.to_owned(),
                is_signed: false,
            });
            work.doer = TaskDoer::Workflow { workflow_id };
            format!(
                "Who does it: the workflow {UNSIGNED_WORKFLOW_NAME} is not \
                 signed yet. Ask for changes and name one of: {}.",
                describe_workflow_choices(context)
            )
        }
        WorkDefect::ForeignRunner => {
            work.runs_on = RunnerTarget::SpecificRunner {
                device_id: DeviceId(FOREIGN_DEVICE_ID.to_owned()),
            };
            format!(
                "Runs on: the chosen runner is not in acme. Ask for changes \
                 and name one of: {}.",
                join_choices(list_runner_names(context), "any free runner")
            )
        }
        WorkDefect::UnknownSkill => {
            work.skills.push(SkillId(foreign_uuid()));
            work.skills.push(SkillId(foreign_uuid()));
            format!(
                "Skills to use: a chosen skill does not exist here. Ask for \
                 changes and name one of: {}.",
                join_choices(list_skill_names(context), "none")
            )
        }
        WorkDefect::InvalidSchedule => {
            work.schedule = Some(Schedule::Hour {
                minute: INVALID_MINUTE,
            });
            "Repeats: minute 75 is not between 0 and 59. Ask for changes and \
             give a valid time."
                .to_owned()
        }
    }
}

fn is_sentence(problem: &str) -> bool {
    let starts_with_capital =
        problem.chars().next().is_some_and(char::is_uppercase);
    starts_with_capital && problem.ends_with('.')
}

fn find_problems(
    context: &DraftingContext,
    work: &WorkDraft,
    wrap: WorkWrapper,
) -> Vec<String> {
    check_item_draft(context, &wrap(work.clone())).problems
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_check_item_draft_property_valid_work_is_kept_trimmed(
        context in context_strategy(),
        title in secret_text_strategy(),
        details in secret_text_strategy(),
        wrap in work_wrapper_strategy(),
    ) {
        let answered =
            valid_work_draft(&context, &padded(&title), &padded(&details));

        let checked = check_item_draft(&context, &wrap(answered.clone()));

        let trimmed = WorkDraft {
            title: title.clone(),
            details: details.clone(),
            ..answered
        };
        prop_assert_eq!(checked.draft, wrap(trimmed));
        prop_assert!(checked.problems.is_empty(), "{:?}", checked.problems);
    }

    #[test]
    fn test_check_item_draft_property_each_work_defect_gives_its_sentence(
        context in context_strategy(),
        defect in work_defect_strategy(),
        wrap in work_wrapper_strategy(),
    ) {
        let mut context = context;
        let mut work = valid_work_draft(&context, "Ship", "Ship it");
        let expected = apply_work_defect(&mut context, &mut work, defect);

        let problems = find_problems(&context, &work, wrap);

        prop_assert_eq!(problems, vec![expected]);
    }

    #[test]
    fn test_check_item_draft_property_lists_work_defects_in_field_order(
        context in context_strategy(),
        wrap in work_wrapper_strategy(),
    ) {
        let mut context = context;
        let mut work = valid_work_draft(&context, "Ship", "Ship it");
        let defects = [
            WorkDefect::EmptyTitle,
            WorkDefect::ForeignProject,
            WorkDefect::UnsignedWorkflow,
            WorkDefect::ForeignRunner,
            WorkDefect::UnknownSkill,
            WorkDefect::InvalidSchedule,
        ];
        let mut expected = Vec::new();
        for defect in defects {
            expected.push(apply_work_defect(&mut context, &mut work, defect));
        }

        let problems = find_problems(&context, &work, wrap);

        prop_assert_eq!(&problems, &expected);
        prop_assert!(problems.iter().all(|problem| is_sentence(problem)));
    }

    #[test]
    fn test_check_item_draft_property_only_a_job_needs_a_schedule(
        context in context_strategy(),
        wrap in work_wrapper_strategy(),
    ) {
        let mut work = valid_work_draft(&context, "Ship", "Ship it");
        work.schedule = None;

        let problems = find_problems(&context, &work, wrap);

        let is_job = matches!(wrap(work.clone()), ItemDraft::Job(_));
        let expected = if is_job {
            vec![JOB_WITHOUT_SCHEDULE.to_owned()]
        } else {
            Vec::new()
        };
        prop_assert_eq!(problems, expected);
    }

    #[test]
    fn test_check_item_draft_property_the_only_project_fills_a_missing_one(
        context in context_strategy(),
        wrap in work_wrapper_strategy(),
    ) {
        let mut context = context;
        context.projects.truncate(1);
        let mut work = valid_work_draft(&context, "Ship", "Ship it");
        let only_project_id = work.project_id;
        work.project_id = None;

        let checked = check_item_draft(&context, &wrap(work.clone()));

        let completed = WorkDraft {
            project_id: only_project_id,
            ..work
        };
        prop_assert_eq!(checked.draft, wrap(completed));
        prop_assert!(checked.problems.is_empty(), "{:?}", checked.problems);
    }

    #[test]
    fn test_check_item_draft_property_work_problems_are_sentences(
        context in context_strategy(),
        title in "\\PC{0,12}",
        project_number in 0..8u128,
        runner_number in 0..8u32,
        minute in 0..120u32,
        wrap in work_wrapper_strategy(),
    ) {
        let mut work = valid_work_draft(&context, &title, "");
        let project_uuid =
            Uuid::from_u128(PROJECT_IDENTIFIER_BASE + project_number);
        work.project_id = Some(ProjectId(project_uuid));
        work.runs_on = RunnerTarget::SpecificRunner {
            device_id: DeviceId(format!("{runner_number:06x}")),
        };
        work.schedule = Some(Schedule::Hour { minute });

        let problems = find_problems(&context, &work, wrap);

        for problem in &problems {
            prop_assert!(is_sentence(problem), "{}", problem);
        }
    }
}
