use orchestration_api::updates::ChangeTopic;

#[derive(Debug)]
pub struct Change<Outcome> {
    pub outcome: Outcome,
    pub effect: ChangeEffect,
}

#[derive(Debug)]
pub enum ChangeEffect {
    Discarded,
    SavedWithoutRecord,
    Recorded(ChangeRecord),
}

#[derive(Debug)]
pub struct ChangeRecord {
    pub topic: ChangeTopic,
    pub event_text: String,
    pub detail: Option<String>,
}

impl<Outcome> Change<Outcome> {
    pub fn recorded(
        outcome: Outcome,
        topic: ChangeTopic,
        event_text: String,
    ) -> Self {
        Self {
            outcome,
            effect: ChangeEffect::Recorded(ChangeRecord {
                topic,
                event_text,
                detail: None,
            }),
        }
    }

    #[must_use]
    pub fn with_detail(self, detail: String) -> Self {
        let effect = match self.effect {
            ChangeEffect::Recorded(record) => {
                ChangeEffect::Recorded(ChangeRecord {
                    detail: Some(detail),
                    ..record
                })
            }
            other_effect => other_effect,
        };
        Self {
            outcome: self.outcome,
            effect,
        }
    }

    pub fn unchanged(outcome: Outcome) -> Self {
        Self {
            outcome,
            effect: ChangeEffect::Discarded,
        }
    }

    pub fn saved_without_record(outcome: Outcome) -> Self {
        Self {
            outcome,
            effect: ChangeEffect::SavedWithoutRecord,
        }
    }
}
