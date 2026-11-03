use std::collections::BTreeMap;

use orchestration_api::accounts::SealedWorkspaceKey;
use orchestration_api::work::RunEvent;
use orchestration_core::identifiers::WorkspaceId;
use orchestration_core::run::{Run, RunStep};
use orchestration_node::content_sealing::{
    WorkspaceKeyring, open_chat_message, open_log_line, open_rule, open_run,
    open_skill, open_task, open_workflow, seal_chat_message, seal_log_line,
    seal_rule, seal_run_event, seal_skill, seal_task, seal_workflow,
};
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::sealing::{
    SEALED_TEXT_PREFIX, seal_for, seal_text,
};
use proptest::prelude::*;
use serde::Serialize;
use uuid::Uuid;

use crate::support::entity_strategies::{
    sample_chat_message, sample_keyring, sample_log_line, sample_rule,
    sample_run, sample_skill, sample_step_with_result, sample_task,
    sample_workflow, secret_text_strategy, secret_texts_strategy,
};
use crate::support::test_device::fail;

const SEALING_CASES: u32 = 32;

pub fn sample_workspace() -> WorkspaceId {
    WorkspaceId(Uuid::from_u128(7))
}

pub fn hides_every_secret<Sealed: Serialize>(
    sealed: &Sealed,
    secrets: &[String],
) -> Result<bool, TestCaseError> {
    let sealed_json = serde_json::to_string(sealed).map_err(fail)?;
    let reveals_secret =
        secrets.iter().any(|secret| sealed_json.contains(secret));
    Ok(!reveals_secret && sealed_json.contains(SEALED_TEXT_PREFIX))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALING_CASES))]

    #[test]
    fn test_seal_task_property_open_task_round_trips(
        details in secret_text_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(sample_workspace()).map_err(fail)?;
        let task = sample_task(&details);

        let sealed_task = seal_task(&workspace_key, &task).map_err(fail)?;

        prop_assert!(hides_every_secret(&sealed_task, &[details])?);
        let opened_task = open_task(&keyring, &sealed_task).map_err(fail)?;
        prop_assert_eq!(opened_task, task);
    }

    #[test]
    fn test_seal_workflow_property_open_workflow_round_trips(
        agent_tasks in secret_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(sample_workspace()).map_err(fail)?;
        let workflow = sample_workflow(&agent_tasks);

        let sealed_workflow =
            seal_workflow(&workspace_key, &workflow).map_err(fail)?;

        prop_assert!(hides_every_secret(&sealed_workflow, &agent_tasks)?);
        let opened_workflow =
            open_workflow(&keyring, &sealed_workflow).map_err(fail)?;
        prop_assert_eq!(opened_workflow, workflow);
    }

    #[test]
    fn test_seal_skill_property_open_skill_round_trips(
        instructions in secret_text_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(sample_workspace()).map_err(fail)?;
        let skill = sample_skill(&instructions);

        let sealed_skill = seal_skill(&workspace_key, &skill).map_err(fail)?;

        prop_assert!(hides_every_secret(&sealed_skill, &[instructions])?);
        let opened_skill = open_skill(&keyring, &sealed_skill).map_err(fail)?;
        prop_assert_eq!(opened_skill, skill);
    }

    #[test]
    fn test_seal_rule_property_open_rule_round_trips(
        details in secret_text_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(sample_workspace()).map_err(fail)?;
        let rule = sample_rule(&details);

        let sealed_rule = seal_rule(&workspace_key, &rule).map_err(fail)?;

        prop_assert!(hides_every_secret(&sealed_rule, &[details])?);
        let opened_rule = open_rule(&keyring, &sealed_rule).map_err(fail)?;
        prop_assert_eq!(opened_rule, rule);
    }

    #[test]
    fn test_seal_chat_message_property_open_chat_message_round_trips(
        text in secret_text_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(sample_workspace()).map_err(fail)?;
        let message = sample_chat_message(&text);

        let sealed_message =
            seal_chat_message(&workspace_key, &message).map_err(fail)?;

        prop_assert!(hides_every_secret(&sealed_message, &[text])?);
        let opened_message =
            open_chat_message(&keyring, &sealed_message).map_err(fail)?;
        prop_assert_eq!(opened_message, message);
    }

    #[test]
    fn test_seal_log_line_property_open_log_line_round_trips(
        text in secret_text_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(sample_workspace()).map_err(fail)?;
        let line = sample_log_line(&text);

        let sealed_line = seal_log_line(&workspace_key, &line).map_err(fail)?;

        prop_assert!(hides_every_secret(&sealed_line, &[text])?);
        let opened_line = open_log_line(&keyring, &sealed_line).map_err(fail)?;
        prop_assert_eq!(opened_line, line);
    }

    #[test]
    fn test_open_run_property_opens_every_log_and_chat_text(
        texts in secret_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(sample_workspace()).map_err(fail)?;
        let run = sample_run(&texts);
        let mut sealed_run = run.clone();
        for line in &mut sealed_run.log {
            *line = seal_log_line(&workspace_key, line).map_err(fail)?;
        }
        for message in &mut sealed_run.chat {
            *message =
                seal_chat_message(&workspace_key, message).map_err(fail)?;
        }

        prop_assert!(hides_every_secret(&sealed_run, &texts)?);
        prop_assert_eq!(open_run(&keyring, &sealed_run).map_err(fail)?, run);
    }

    #[test]
    fn test_seal_run_event_property_hides_log_and_chat_text(
        text in secret_text_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(sample_workspace()).map_err(fail)?;
        let events = [
            RunEvent::LogAppended { line: sample_log_line(&text) },
            RunEvent::ChatAppended { message: sample_chat_message(&text) },
        ];

        for event in &events {
            let sealed_event =
                seal_run_event(&workspace_key, event).map_err(fail)?;
            let secrets = std::slice::from_ref(&text);
            prop_assert!(hides_every_secret(&sealed_event, secrets)?);
        }
    }

    #[test]
    fn test_seal_run_event_property_hides_step_results(
        text in secret_text_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(sample_workspace()).map_err(fail)?;
        let event = RunEvent::StepResultRecorded {
            step_name: "plan".to_owned(),
            result: text.clone(),
            outcome: None,
        };

        let sealed_event =
            seal_run_event(&workspace_key, &event).map_err(fail)?;

        let secrets = std::slice::from_ref(&text);
        prop_assert!(hides_every_secret(&sealed_event, secrets)?);
        let RunEvent::StepResultRecorded { result, .. } = &sealed_event else {
            return Err(TestCaseError::fail("the event kind changed"));
        };
        prop_assert_eq!(keyring.open_text(result).map_err(fail)?, text);
    }

    #[test]
    fn test_open_run_property_opens_every_step_result(
        texts in secret_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(sample_workspace()).map_err(fail)?;
        let mut steps = Vec::new();
        let mut sealed_steps = Vec::new();
        for (position, text) in texts.iter().enumerate() {
            let step = sample_step_with_result(position, text);
            let sealed_result = seal_text(&workspace_key, text).map_err(fail)?;
            sealed_steps.push(RunStep {
                result: Some(sealed_result),
                ..step.clone()
            });
            steps.push(step);
        }
        let run = Run { steps, ..sample_run(&[]) };
        let sealed_run = Run {
            steps: sealed_steps,
            ..run.clone()
        };

        prop_assert!(hides_every_secret(&sealed_run, &texts)?);
        prop_assert_eq!(open_run(&keyring, &sealed_run).map_err(fail)?, run);
    }

    #[test]
    fn test_open_text_property_a_keyring_without_the_key_fails(
        details in secret_text_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(sample_workspace()).map_err(fail)?;
        let (_, other_keyring) =
            sample_keyring(sample_workspace()).map_err(fail)?;
        let sealed_task =
            seal_task(&workspace_key, &sample_task(&details)).map_err(fail)?;

        prop_assert!(open_task(&other_keyring, &sealed_task).is_err());
    }

    #[test]
    fn test_open_task_property_arbitrary_details_give_defined_error(
        arbitrary_details in "\\PC{0,120}",
    ) {
        let (_, keyring) = sample_keyring(sample_workspace()).map_err(fail)?;
        let opened = open_task(&keyring, &sample_task(&arbitrary_details));

        prop_assert!(opened.is_err());
        let message = opened.err().map(|error| error.to_string());
        prop_assert!(message.is_some_and(|text| !text.is_empty()));
    }

    #[test]
    fn test_open_sealed_keys_property_opens_keys_sealed_for_this_device(
        details in secret_text_strategy(),
        workspace_bits in any::<u128>(),
    ) {
        let identity = DeviceIdentity::generate().map_err(fail)?;
        let workspace_id = WorkspaceId(Uuid::from_u128(workspace_bits));
        let (workspace_key, _) = sample_keyring(workspace_id).map_err(fail)?;
        let sealing_key = identity.public_identity().sealing_public_key;
        let key_bytes = workspace_key.to_bytes();
        let sealed_key = SealedWorkspaceKey {
            workspace_id,
            sealed_key: seal_for(&sealing_key, key_bytes.as_ref())
                .map_err(fail)?,
        };

        let keyring =
            WorkspaceKeyring::open_sealed_keys(&identity, &[sealed_key])
                .map_err(fail)?;
        let task = sample_task(&details);
        let sealed_task = seal_task(&workspace_key, &task).map_err(fail)?;

        prop_assert!(keyring.key_for(workspace_id).is_ok());
        let opened_task = open_task(&keyring, &sealed_task).map_err(fail)?;
        prop_assert_eq!(opened_task, task);
    }

    #[test]
    fn test_key_for_property_unknown_workspace_gives_defined_error(
        workspace_bits in any::<u128>(),
    ) {
        let keyring = WorkspaceKeyring::from_keys(BTreeMap::new());
        let workspace_id = WorkspaceId(Uuid::from_u128(workspace_bits));

        prop_assert!(keyring.key_for(workspace_id).is_err());
    }
}
