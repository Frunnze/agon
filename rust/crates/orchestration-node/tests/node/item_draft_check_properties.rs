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

use crate::support::drafting_samples::{
    FOREIGN_DEVICE_ID, context_strategy, foreign_uuid, padded,
    valid_work_draft,
};
use crate::support::entity_strategies::secret_text_strategy;

const CHECK_CASES: u32 = 32;
const UNSIGNED_WORKFLOW_NAME: &str = "unsigned-flow";
const INVALID_MINUTE: u32 = 75;
const PROJECT_IDENTIFIER_BASE: u128 = 0x100;
const JOB_WITHOUT_SCHEDULE: &str =
    "A job needs a schedule. Ask for changes and say how often it repeats.";

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

fn apply_work_defect(
    context: &mut DraftingContext,
    work: &mut WorkDraft,
    defect: WorkDefect,
) -> String {
    match defect {
        WorkDefect::EmptyTitle => {
            " \n ".clone_into(&mut work.title);
            "The agent wrote nothing for what should be done.".to_owned()
        }
        WorkDefect::NoProject => {
            work.project_id = None;
            "No project in acme fits this. Ask for changes and name the \
             project, or add the project first."
                .to_owned()
        }
        WorkDefect::ForeignProject => {
            work.project_id = Some(ProjectId(foreign_uuid()));
            "The agent chose a project that is not in acme.".to_owned()
        }
        WorkDefect::UnknownWorkflow => {
            work.doer = TaskDoer::Workflow {
                workflow_id: WorkflowId(foreign_uuid()),
            };
            "The agent chose a workflow that does not exist here.".to_owned()
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
                "The workflow {UNSIGNED_WORKFLOW_NAME} is not signed yet, so \
                 it cannot do the work."
            )
        }
        WorkDefect::ForeignRunner => {
            work.runs_on = RunnerTarget::SpecificRunner {
                device_id: DeviceId(FOREIGN_DEVICE_ID.to_owned()),
            };
            "The agent chose a runner that is not in acme.".to_owned()
        }
        WorkDefect::UnknownSkill => {
            work.skills.push(SkillId(foreign_uuid()));
            work.skills.push(SkillId(foreign_uuid()));
            "The agent chose a skill that does not exist here.".to_owned()
        }
        WorkDefect::InvalidSchedule => {
            work.schedule = Some(Schedule::Hour {
                minute: INVALID_MINUTE,
            });
            "The schedule is not valid: minute 75 is not between 0 and 59."
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
