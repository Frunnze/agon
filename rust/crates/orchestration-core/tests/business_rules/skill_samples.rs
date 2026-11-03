use chrono::{DateTime, TimeZone, Utc};
use orchestration_core::identifiers::{RunId, SkillId};
use orchestration_core::library::{
    Skill, SkillChangeOrigin, SkillImprovement, SkillSource, SkillUsage,
};
use orchestration_core::scope::Scope;
use proptest::prelude::*;
use uuid::Uuid;

const FIRST_SAVE_SECOND: i64 = 1_700_000_000;

pub fn skill_named(
    number: u128,
    name: &str,
    improvement: SkillImprovement,
) -> Skill {
    Skill {
        id: SkillId(Uuid::from_u128(number)),
        name: name.to_owned(),
        summary: format!("What {name} does"),
        instructions: format!("Follow the {name} steps."),
        scope: Scope::everywhere(),
        usage: SkillUsage::Automatic,
        source: SkillSource::Created,
        improvement,
        history: Vec::new(),
    }
}

pub fn saved_at(offset_seconds: i64) -> DateTime<Utc> {
    Utc.timestamp_opt(FIRST_SAVE_SECOND + offset_seconds, 0)
        .single()
        .unwrap_or(DateTime::UNIX_EPOCH)
}

pub fn improvement() -> impl Strategy<Value = SkillImprovement> {
    prop_oneof![
        Just(SkillImprovement::Never),
        Just(SkillImprovement::AskMe),
        Just(SkillImprovement::Auto),
    ]
}

pub fn agent_origin() -> impl Strategy<Value = SkillChangeOrigin> {
    (any::<u128>(), any::<bool>()).prop_map(|(number, was_approved)| {
        let run_id = RunId(Uuid::from_u128(number));
        if was_approved {
            SkillChangeOrigin::ApprovedAgentRun { run_id }
        } else {
            SkillChangeOrigin::AutomaticAgentRun { run_id }
        }
    })
}

pub fn any_origin() -> impl Strategy<Value = SkillChangeOrigin> {
    prop_oneof![Just(SkillChangeOrigin::PersonEdit), agent_origin()]
}

pub fn instruction_text() -> impl Strategy<Value = String> {
    "[a-z][a-z .\n]{0,60}[a-z.]"
}
