use orchestration_hub::claude_control::{
    write_interrupt_request, write_user_message,
};
use tokio::sync::mpsc::UnboundedSender;

use crate::run_error::RunError;
use crate::user_message_watch::NewUserMessages;

const INTERRUPT_REQUEST_PREFIX: &str = "interrupt-";

pub(crate) struct LiveInput {
    input_lines: Option<UnboundedSender<String>>,
    unfinished_turns: usize,
    awaited_delivery: Option<NewUserMessages>,
}

impl LiveInput {
    pub(crate) fn open(
        input_lines: UnboundedSender<String>,
        prompt_line: String,
    ) -> Result<Self, RunError> {
        let live_input = Self {
            input_lines: Some(input_lines),
            unfinished_turns: 1,
            awaited_delivery: None,
        };
        live_input.send(prompt_line)?;
        Ok(live_input)
    }

    pub(crate) fn send(&self, line: String) -> Result<(), RunError> {
        let Some(input_lines) = &self.input_lines else {
            return Err(RunError::AgentInputClosed);
        };
        input_lines
            .send(line)
            .map_err(|_unsent_line| RunError::AgentInputClosed)
    }

    pub(crate) fn is_interruptible(&self) -> bool {
        self.input_lines.is_some() && self.awaited_delivery.is_none()
    }

    pub(crate) fn interrupt(
        &mut self,
        new_messages: NewUserMessages,
    ) -> Result<(), RunError> {
        let request_id = name_interrupt_request(&new_messages);
        self.send(write_interrupt_request(&request_id))?;
        self.awaited_delivery = Some(new_messages);
        Ok(())
    }

    pub(crate) fn deliver_answered(
        &mut self,
        answered_request_id: &str,
    ) -> Result<Option<NewUserMessages>, RunError> {
        let answered = self.awaited_delivery.take_if(|awaited| {
            name_interrupt_request(awaited) == answered_request_id
        });
        let Some(delivery) = answered else {
            return Ok(None);
        };

        self.send(write_user_message(&delivery.prompt))?;
        self.unfinished_turns += 1;
        Ok(Some(delivery))
    }

    pub(crate) fn end_turn(&mut self) {
        self.unfinished_turns = self.unfinished_turns.saturating_sub(1);
        let is_idle = self.unfinished_turns == 0;
        if is_idle && self.awaited_delivery.is_none() {
            self.input_lines = None;
        }
    }
}

fn name_interrupt_request(new_messages: &NewUserMessages) -> String {
    let answered_messages = new_messages.answered_messages;
    format!("{INTERRUPT_REQUEST_PREFIX}{answered_messages}")
}
