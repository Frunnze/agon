use orchestration_hub::agent_event::AgentEvent;

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct AgentTranscript {
    pub final_message: Option<String>,
    pub session: Option<String>,
    pub failure_reason: Option<String>,
    pub answered_messages: usize,
}

impl AgentTranscript {
    pub(crate) fn record(self, agent_events: &[AgentEvent]) -> Self {
        let mut transcript = self;
        for agent_event in agent_events {
            transcript = transcript.record_event(agent_event);
        }
        transcript
    }

    pub(crate) fn continue_with(self, reply: Self) -> Self {
        Self {
            final_message: reply.final_message.or(self.final_message),
            session: reply.session.or(self.session),
            failure_reason: reply.failure_reason.or(self.failure_reason),
            answered_messages: reply.answered_messages,
        }
    }

    fn record_event(self, agent_event: &AgentEvent) -> Self {
        match agent_event {
            AgentEvent::Said(text) => Self {
                final_message: Some(text.clone()),
                ..self
            },
            AgentEvent::SessionStarted(session) => Self {
                session: Some(session.clone()),
                ..self
            },
            AgentEvent::Failed(reason) => Self {
                failure_reason: Some(reason.clone()),
                ..self
            },
            AgentEvent::UsedTool(_)
            | AgentEvent::ToolFailed(_)
            | AgentEvent::Finished
            | AgentEvent::AskedForApproval(_) => self,
        }
    }
}
