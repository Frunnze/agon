use std::collections::BTreeMap;

use orchestration_core::agent_place::AgentPlace;
use orchestration_core::approval::ApprovalAction;
use orchestration_core::device::{Runner, RunnerLink};
use orchestration_core::identifiers::{DeviceId, RunId, TaskId, WorkflowId};
use orchestration_core::run::{RunStep, StepStatus};
use orchestration_node::views::{
    RunnerSummary, describe_approval_action, describe_run_progress,
    describe_runner_summary, find_latest_run, summarize_runners,
};
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::support::entity_strategies::sample_run;

const MOST_STEPS: usize = 6;
const MOST_RUNNERS: usize = 6;
const MOST_SLOTS: u32 = 8;

fn step_status_strategy() -> impl Strategy<Value = StepStatus> {
    prop_oneof![
        Just(StepStatus::Waiting),
        Just(StepStatus::Running),
        Just(StepStatus::WaitingForApproval),
        Just(StepStatus::Done),
        Just(StepStatus::Failed),
        Just(StepStatus::Skipped),
    ]
}

fn runner_strategy() -> impl Strategy<Value = Runner> {
    (0..MOST_SLOTS, 0..MOST_SLOTS, any::<bool>(), "[a-z]{1,8}")
        .prop_map(build_runner)
}

fn build_runner(parts: (u32, u32, bool, String)) -> Runner {
    let (slots_total, slots_busy, online, name) = parts;
    Runner {
        device_id: DeviceId(name),
        labels: Vec::new(),
        slots_total,
        slots_busy,
        link: RunnerLink::Direct,
        online,
        accepting_new_runs: true,
        offers: vec![AgentPlace::Container],
        allowed_hosts: Vec::new(),
        cached_repositories: Vec::new(),
    }
}

fn is_finished(status: StepStatus) -> bool {
    matches!(status, StepStatus::Done | StepStatus::Skipped)
}

#[test]
fn runner_summary_text_matches_the_design() {
    let summary = RunnerSummary {
        runner_count: 4,
        online_count: 3,
        free_slot_count: 5,
    };

    assert_eq!(
        describe_runner_summary(&summary),
        "3 of 4 online · 5 free slots"
    );
}

#[test]
fn push_approval_text_matches_the_design() {
    let action = ApprovalAction::PushCommits {
        repository: "acme/app".to_owned(),
        branch: "release".to_owned(),
        commits: vec!["a".to_owned(), "b".to_owned(), "c".to_owned()],
    };

    let description = describe_approval_action(&action, &BTreeMap::new());

    assert_eq!(description, "Push 3 commits to release");
}

proptest! {
    #[test]
    fn test_describe_run_progress_property_points_at_the_first_unfinished_step(
        statuses in vec(step_status_strategy(), 0..MOST_STEPS),
    ) {
        let mut run = sample_run(&[]);
        for (position, status) in statuses.iter().enumerate() {
            run.steps.push(RunStep {
                name: format!("step-{position}"),
                agent_id: None,
                runner: None,
                status: *status,
                started_at: None,
                finished_at: None,
                result: None,
                outcome: None,
                loop_source: None,
                earlier_rounds: Vec::new(),
            });
        }

        let progress = describe_run_progress(&run);

        let first_unfinished = statuses
            .iter()
            .position(|status| !is_finished(*status));
        prop_assert_eq!(progress.step_count, statuses.len());
        let current_number =
            progress.current_step.as_ref().map(|current| current.number);
        let expected_number = first_unfinished.map(|index| index + 1);
        prop_assert_eq!(current_number, expected_number);
        if let Some(current) = progress.current_step {
            prop_assert!(current.number >= 1);
            prop_assert!(current.number <= progress.step_count);
        }
    }

    #[test]
    fn test_summarize_runners_property_counts_free_slots_of_online_runners(
        runners in vec(runner_strategy(), 0..MOST_RUNNERS),
    ) {
        let summary = summarize_runners(&runners);

        let expected_free_slots: u32 = runners
            .iter()
            .filter(|runner| runner.online)
            .map(|runner| runner.slots_total.saturating_sub(runner.slots_busy))
            .sum();
        prop_assert_eq!(summary.runner_count, runners.len());
        prop_assert!(summary.online_count <= summary.runner_count);
        prop_assert_eq!(summary.free_slot_count, expected_free_slots);
    }

    #[test]
    fn test_describe_runner_summary_property_names_every_count(
        runner_count in 0_usize..50,
        online_share in 0_usize..50,
        free_slot_count in 0_u32..50,
    ) {
        let online_count = online_share.min(runner_count);
        let summary = RunnerSummary {
            runner_count,
            online_count,
            free_slot_count,
        };

        let text = describe_runner_summary(&summary);

        let online_text = format!("{online_count} of {runner_count} online");
        prop_assert!(text.starts_with(&online_text));
        let slot_word = if free_slot_count == 1 { "slot" } else { "slots" };
        let ending = format!(" · {free_slot_count} free {slot_word}");
        prop_assert!(text.ends_with(&ending));
    }

    #[test]
    fn test_describe_approval_action_property_names_the_workflow(
        workflow_bits in any::<u128>(),
        workflow_name in "[a-z-]{1,20}",
    ) {
        let workflow_id = WorkflowId(Uuid::from_u128(workflow_bits));
        let names = BTreeMap::from([(workflow_id, workflow_name.clone())]);
        let action = ApprovalAction::SignWorkflow { workflow_id };

        let description = describe_approval_action(&action, &names);

        prop_assert_eq!(description, format!("Sign workflow {workflow_name}"));
    }

    #[test]
    fn test_describe_approval_action_property_leads_with_the_summary(
        tool in "[A-Za-z]{1,12}",
        summary in "[A-Z][a-z ]{0,40}",
        command in "[a-z ./-]{1,40}",
    ) {
        let action = ApprovalAction::RunCommand {
            tool,
            summary: summary.clone(),
            command,
        };

        let description = describe_approval_action(&action, &BTreeMap::new());

        prop_assert_eq!(description, summary);
    }

    #[test]
    fn test_find_latest_run_property_picks_the_highest_number_of_the_task(
        numbers in proptest::collection::vec(1_u32..100, 0..MOST_STEPS),
    ) {
        let task_id = TaskId(Uuid::from_u128(1));
        let mut runs = Vec::new();
        for (position, number) in numbers.iter().enumerate() {
            let mut run = sample_run(&[]);
            let run_bits = u128::try_from(position).unwrap_or_default();
            run.id = RunId(Uuid::from_u128(run_bits));
            run.number = *number;
            runs.push(run);
        }

        let latest_run = find_latest_run(&runs, task_id);
        let latest_number = latest_run.map(|run| run.number);

        prop_assert_eq!(latest_number, numbers.iter().copied().max());
    }
}
