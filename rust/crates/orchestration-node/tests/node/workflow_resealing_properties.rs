use orchestration_node::content_sealing::{
    open_workflow, reseal_workflow, seal_workflow,
};
use proptest::prelude::*;
use proptest::sample::Index;

use crate::content_sealing_properties::{
    hides_every_secret, sample_workspace,
};
use crate::support::entity_strategies::{
    sample_keyring, sample_workflow, secret_text_strategy,
    secret_texts_strategy,
};
use crate::support::test_device::fail;

proptest! {
    #[test]
    fn test_reseal_workflow_property_keeps_every_unchanged_sealed_text(
        agent_tasks in secret_texts_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(sample_workspace()).map_err(fail)?;
        let workflow = sample_workflow(&agent_tasks);
        let stored_workflow =
            seal_workflow(&workspace_key, &workflow).map_err(fail)?;

        let resealed_workflow =
            reseal_workflow(&workspace_key, &workflow, &stored_workflow)
                .map_err(fail)?;

        prop_assert_eq!(resealed_workflow, stored_workflow);
    }

    #[test]
    fn test_reseal_workflow_property_seals_only_the_changed_step_anew(
        agent_tasks in secret_texts_strategy(),
        changed_step in any::<Index>(),
        changed_task in secret_text_strategy(),
    ) {
        let changed_position = changed_step.index(agent_tasks.len());
        prop_assume!(agent_tasks[changed_position] != changed_task);
        let (workspace_key, keyring) =
            sample_keyring(sample_workspace()).map_err(fail)?;
        let workflow = sample_workflow(&agent_tasks);
        let stored_workflow =
            seal_workflow(&workspace_key, &workflow).map_err(fail)?;
        let mut changed_tasks = agent_tasks.clone();
        changed_tasks[changed_position] = changed_task.clone();
        let changed_workflow = sample_workflow(&changed_tasks);

        let resealed_workflow = reseal_workflow(
            &workspace_key,
            &changed_workflow,
            &stored_workflow,
        )
        .map_err(fail)?;

        let step_pairs = resealed_workflow
            .agents
            .iter()
            .zip(&stored_workflow.agents)
            .enumerate();
        for (position, (resealed_step, stored_step)) in step_pairs {
            let is_changed_step = position == changed_position;
            let is_sealed_anew = resealed_step.task != stored_step.task;
            prop_assert_eq!(is_sealed_anew, is_changed_step);
        }
        prop_assert!(hides_every_secret(&resealed_workflow, &changed_tasks)?);
        let opened_workflow =
            open_workflow(&keyring, &resealed_workflow).map_err(fail)?;
        prop_assert_eq!(opened_workflow, changed_workflow);
    }

    #[test]
    fn test_reseal_workflow_property_seals_anew_for_another_workspace(
        agent_tasks in secret_texts_strategy(),
    ) {
        let (other_workspace_key, _) =
            sample_keyring(sample_workspace()).map_err(fail)?;
        let (workspace_key, keyring) =
            sample_keyring(sample_workspace()).map_err(fail)?;
        let workflow = sample_workflow(&agent_tasks);
        let stored_workflow =
            seal_workflow(&other_workspace_key, &workflow).map_err(fail)?;

        let resealed_workflow =
            reseal_workflow(&workspace_key, &workflow, &stored_workflow)
                .map_err(fail)?;

        let step_pairs =
            resealed_workflow.agents.iter().zip(&stored_workflow.agents);
        for (resealed_step, stored_step) in step_pairs {
            prop_assert_ne!(&resealed_step.task, &stored_step.task);
        }
        let opened_workflow =
            open_workflow(&keyring, &resealed_workflow).map_err(fail)?;
        prop_assert_eq!(opened_workflow, workflow);
    }
}
