use orchestration_api::work::{AnswerPersonStepRequest, OpenPersonStep};
use orchestration_core::identifiers::RunId;
use orchestration_core::run::Run;
use orchestration_core::step_outcomes::match_choice;
use orchestration_security::sealing::seal_text;

use crate::content_sealing::open_run;
use crate::node::DeviceSession;
use crate::node_error::NodeError;

const ANSWER_FIELD: &str = "answer";
const OPEN_STEP_KIND: &str = "open person step";

#[derive(Clone, Copy, Debug)]
pub(super) struct AskedQuestion<'question> {
    pub run_id: RunId,
    pub step_name: &'question str,
}

pub(super) async fn list_open_person_steps(
    session: &DeviceSession,
) -> Result<Vec<OpenPersonStep>, NodeError> {
    let mut opened_steps = Vec::new();
    for open_step in session.client().list_person_steps().await? {
        let question = session.keyring.open_text(&open_step.question)?;
        opened_steps.push(OpenPersonStep {
            question,
            ..open_step
        });
    }
    Ok(opened_steps)
}

pub(super) async fn answer_person_step(
    session: &DeviceSession,
    question: AskedQuestion<'_>,
    answer: &str,
) -> Result<Run, NodeError> {
    if answer.trim().is_empty() {
        return Err(NodeError::EmptyText {
            field: ANSWER_FIELD,
        });
    }
    let client = session.client();
    let open_steps = client.list_person_steps().await?;
    let open_step = open_steps.iter().find(|open_step| {
        open_step.run_id == question.run_id
            && open_step.step_name == question.step_name
    });
    let Some(open_step) = open_step else {
        return Err(NodeError::NotFound {
            kind: OPEN_STEP_KIND,
            identifier: question.step_name.to_owned(),
        });
    };

    let choice = choose_answer(answer, &open_step.choices)?;
    let workspace_key = session.keyring.key_for(open_step.workspace_id)?;
    let request = AnswerPersonStepRequest {
        answer: seal_text(workspace_key, answer)?,
        choice,
    };
    let run = client
        .answer_person_step(question.run_id, question.step_name, &request)
        .await?;
    open_run(&session.keyring, &run)
}

fn choose_answer(
    answer: &str,
    choices: &[String],
) -> Result<Option<String>, NodeError> {
    if choices.is_empty() {
        return Ok(None);
    }
    match match_choice(answer, choices) {
        Some(choice) => Ok(Some(choice)),
        None => Err(NodeError::UnmatchedAnswer {
            choices: choices.to_vec(),
        }),
    }
}
