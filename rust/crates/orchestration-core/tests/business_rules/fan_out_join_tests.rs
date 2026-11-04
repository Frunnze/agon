use orchestration_core::identifiers::DeviceId;
use orchestration_core::run::{Run, RunStatus, StepStatus};
use orchestration_core::run_routing::is_step_claimable;
use orchestration_core::workflow::Workflow;
use proptest::prelude::*;

use crate::routing_fixtures::{
    connect, finish_step, fresh_run, routing_workflow, step_named,
};

const SOURCE: u128 = 0;
const FEWEST_REVIEWERS: u128 = 2;
const MOST_REVIEWERS: u128 = 5;
const MOST_ROUNDS: u32 = 3;
const MOST_FORK_BRANCHES: u128 = 4;
const MOST_PLAIN_BRANCHES: u128 = 2;
const LOOP_OUTCOME: &str = "again";
const CLAIMING_RUNNER: &str = "studio-mac";

fn name_step(number: u128) -> String {
    format!("step-{number}")
}

fn join_number(branch_count: u128) -> u128 {
    branch_count + 1
}

fn review_workflow(
    reviewer_count: u128,
    round_limit: Option<u32>,
) -> Workflow {
    let join = join_number(reviewer_count);
    let mut connections = Vec::new();
    for reviewer in 1..=reviewer_count {
        connections.push(connect(SOURCE, reviewer, None, None));
        connections.push(connect(reviewer, join, None, None));
    }
    if let Some(round_limit) = round_limit {
        let back =
            connect(join, SOURCE, Some(LOOP_OUTCOME), Some(round_limit));
        connections.push(back);
    }
    routing_workflow(join + 1, connections)
}

fn fork_join_workflow(fork_branches: u128, plain_branches: u128) -> Workflow {
    let branch_count = fork_branches + plain_branches;
    let join = join_number(branch_count);
    let mut connections = Vec::new();
    for branch in 1..=branch_count {
        let condition = (branch <= fork_branches).then(|| name_step(branch));
        let source_connection =
            connect(SOURCE, branch, condition.as_deref(), None);
        connections.push(source_connection);
        connections.push(connect(branch, join, None, None));
    }
    routing_workflow(join + 1, connections)
}

fn claimable_names(run: &Run, workflow: &Workflow) -> Vec<String> {
    let mut names = Vec::new();
    for step in &run.steps {
        if is_step_claimable(run, step, Some(workflow)) {
            names.push(step.name.clone());
        }
    }
    names
}

fn give_to_runner(run: &Run, step_name: &str) -> Run {
    let mut claimed = run.clone();
    for step in &mut claimed.steps {
        if step.name == step_name {
            step.runner = Some(DeviceId(CLAIMING_RUNNER.to_owned()));
        }
    }
    claimed
}

fn is_join_claimable(run: &Run, workflow: &Workflow, join: u128) -> bool {
    let join_step = step_named(run, &name_step(join));
    is_step_claimable(run, join_step, Some(workflow))
}

fn reviewers_in_any_order() -> impl Strategy<Value = Vec<u128>> {
    (FEWEST_REVIEWERS..=MOST_REVIEWERS).prop_flat_map(|reviewer_count| {
        let reviewers: Vec<u128> = (1..=reviewer_count).collect();
        Just(reviewers).prop_shuffle()
    })
}

fn finish_reviewers_checking_the_join(
    run: &Run,
    workflow: &Workflow,
    finishing_order: &[u128],
) -> Result<Run, TestCaseError> {
    let join = join_number(u128::try_from(finishing_order.len())?);
    let mut reviewed = run.clone();
    for reviewer in finishing_order {
        prop_assert!(!is_join_claimable(&reviewed, workflow, join));
        reviewed =
            finish_step(&reviewed, workflow, &name_step(*reviewer), None);
    }
    prop_assert!(is_join_claimable(&reviewed, workflow, join));
    Ok(reviewed)
}

proptest! {
    #[test]
    fn test_is_step_claimable_property_offers_every_ready_reviewer_at_once(
        reviewer_count in FEWEST_REVIEWERS..=MOST_REVIEWERS,
        claimed_count in 0..MOST_REVIEWERS,
    ) {
        let workflow = review_workflow(reviewer_count, None);
        let fresh = fresh_run(&workflow);
        let mut run = finish_step(&fresh, &workflow, "step-0", None);
        let claimed_count = claimed_count.min(reviewer_count - 1);
        for reviewer in 1..=claimed_count {
            run = give_to_runner(&run, &name_step(reviewer));
        }

        let claimable = claimable_names(&run, &workflow);

        let expected: Vec<String> =
            (claimed_count + 1..=reviewer_count).map(name_step).collect();
        prop_assert_eq!(claimable, expected);
    }

    #[test]
    fn test_is_step_claimable_property_join_waits_for_every_reviewer(
        finishing_order in reviewers_in_any_order(),
    ) {
        let reviewer_count = u128::try_from(finishing_order.len())?;
        let workflow = review_workflow(reviewer_count, None);
        let fresh = fresh_run(&workflow);
        let run = finish_step(&fresh, &workflow, "step-0", None);

        let reviewed = finish_reviewers_checking_the_join(
            &run,
            &workflow,
            &finishing_order,
        )?;

        let join = join_number(reviewer_count);
        let claimable = claimable_names(&reviewed, &workflow);
        prop_assert_eq!(claimable, vec![name_step(join)]);
    }

    #[test]
    fn test_is_step_claimable_property_join_waits_again_after_a_loop_round(
        finishing_order in reviewers_in_any_order(),
        round_limit in 1..=MOST_ROUNDS,
    ) {
        let reviewer_count = u128::try_from(finishing_order.len())?;
        let join_name = name_step(join_number(reviewer_count));
        let workflow = review_workflow(reviewer_count, Some(round_limit));
        let mut run = fresh_run(&workflow);

        for round in 0..=round_limit {
            prop_assert_eq!(claimable_names(&run, &workflow), vec!["step-0"]);
            run = finish_step(&run, &workflow, "step-0", None);
            run = finish_reviewers_checking_the_join(
                &run,
                &workflow,
                &finishing_order,
            )?;
            run = finish_step(&run, &workflow, &join_name, Some(LOOP_OUTCOME));
            if round < round_limit {
                let join_step = step_named(&run, &join_name);
                prop_assert_eq!(join_step.status, StepStatus::Waiting);
            }
        }

        prop_assert_eq!(run.status, RunStatus::Done);
        let join_step = step_named(&run, &join_name);
        let earlier_rounds = usize::try_from(round_limit)?;
        prop_assert_eq!(join_step.earlier_rounds.len(), earlier_rounds);
    }

    #[test]
    fn test_is_step_claimable_property_join_waits_only_for_taken_branches(
        fork_branches in 1..=MOST_FORK_BRANCHES,
        plain_branches in 0..=MOST_PLAIN_BRANCHES,
        chosen in any::<prop::sample::Index>(),
        shuffle_seed in any::<prop::sample::Index>(),
    ) {
        let workflow = fork_join_workflow(fork_branches, plain_branches);
        let chosen_branch = 1 + u128::try_from(
            chosen.index(usize::try_from(fork_branches)?),
        )?;
        let branch_count = fork_branches + plain_branches;
        let join = join_number(branch_count);
        let mut taken: Vec<u128> = vec![chosen_branch];
        taken.extend(fork_branches + 1..=branch_count);
        let rotation = shuffle_seed.index(taken.len());
        taken.rotate_left(rotation);

        let fresh = fresh_run(&workflow);
        let chosen_outcome = name_step(chosen_branch);
        let mut run =
            finish_step(&fresh, &workflow, "step-0", Some(&chosen_outcome));

        let mut expected_claimable = taken.clone();
        expected_claimable.sort_unstable();
        let expected_names: Vec<String> =
            expected_claimable.into_iter().map(name_step).collect();
        prop_assert_eq!(claimable_names(&run, &workflow), expected_names);
        for branch in 1..=fork_branches {
            let status = step_named(&run, &name_step(branch)).status;
            let expected = if branch == chosen_branch {
                StepStatus::Waiting
            } else {
                StepStatus::Skipped
            };
            prop_assert_eq!(status, expected);
        }
        for branch in &taken {
            prop_assert!(!is_join_claimable(&run, &workflow, join));
            run = finish_step(&run, &workflow, &name_step(*branch), None);
        }
        prop_assert!(is_join_claimable(&run, &workflow, join));
    }
}
