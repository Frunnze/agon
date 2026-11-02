use axum::http::StatusCode;
use orchestration_api::catalog::SaveSkillRequest;
use orchestration_core::library::{Skill, SkillSource, SkillUsage};
use proptest::prelude::*;
use proptest::sample::Index;

use crate::fixtures::create_account;
use crate::library_fixtures::{
    CHANGED_DETAILS, MOST_ITEMS, list_skills, sample_skill, save_skill,
    skill_path,
};
use crate::test_client::{TestServer, block_on};

proptest! {
    #![proptest_config(ProptestConfig::with_cases(8))]

    #[test]
    fn test_update_skill_property_replaces_fields_but_keeps_the_source(
        name in "[a-z][a-z0-9-]{0,20}",
        summary in "[A-Za-z][A-Za-z ]{0,30}",
        is_automatic in any::<bool>(),
    ) {
        let test = TestServer::start();
        let original = sample_skill("ios-release");
        let usage = if is_automatic {
            SkillUsage::Automatic
        } else {
            SkillUsage::WhenChosen
        };
        let (status, stored) = block_on(async {
            let account = create_account(&test).await;
            save_skill(&test, &account, &original).await;
            let changed = Skill {
                name: name.clone(),
                summary: summary.clone(),
                instructions: CHANGED_DETAILS.to_owned(),
                usage,
                source: SkillSource::BuiltIn,
                ..original.clone()
            };
            let request = SaveSkillRequest { skill: changed };
            let path = skill_path(original.id);
            let response = test.put(&account.owner, &path, &request).await;
            (response.status, list_skills(&test, &account).await)
        });

        prop_assert_eq!(status, StatusCode::OK);
        prop_assert_eq!(stored.len(), 1);
        prop_assert_eq!(stored[0].id, original.id);
        prop_assert_eq!(stored[0].source, SkillSource::Created);
        prop_assert_eq!(&stored[0].name, &name);
        prop_assert_eq!(&stored[0].summary, &summary);
        prop_assert_eq!(&stored[0].instructions, CHANGED_DETAILS);
        prop_assert_eq!(stored[0].usage, usage);
    }

    #[test]
    fn test_update_skill_property_rejects_invalid_names(
        name in "[a-z]{0,3}[A-Z_ ][a-z]{0,3}",
    ) {
        let test = TestServer::start();
        let original = sample_skill("ios-release");
        let (status, stored) = block_on(async {
            let account = create_account(&test).await;
            save_skill(&test, &account, &original).await;
            let changed = Skill {
                name,
                ..original.clone()
            };
            let request = SaveSkillRequest { skill: changed };
            let path = skill_path(original.id);
            let response = test.put(&account.owner, &path, &request).await;
            (response.status, list_skills(&test, &account).await)
        });

        prop_assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        prop_assert_eq!(stored, vec![original]);
    }

    #[test]
    fn test_delete_skill_property_removes_only_that_skill(
        count in 1..MOST_ITEMS,
        position in any::<Index>(),
    ) {
        let test = TestServer::start();
        let skills: Vec<Skill> = (0..count)
            .map(|number| sample_skill(&format!("skill-{number}")))
            .collect();
        let deleted = skills[position.index(count)].clone();
        let (status, repeated, stored) = block_on(async {
            let account = create_account(&test).await;
            for skill in &skills {
                save_skill(&test, &account, skill).await;
            }
            let path = skill_path(deleted.id);
            let response = test.delete(&account.owner, &path).await;
            let repeated = test.delete(&account.owner, &path).await;
            let stored = list_skills(&test, &account).await;
            (response.status, repeated.status, stored)
        });

        prop_assert_eq!(status, StatusCode::NO_CONTENT);
        prop_assert_eq!(repeated, StatusCode::NOT_FOUND);
        prop_assert_eq!(stored.len(), count - 1);
        prop_assert!(stored.iter().all(|skill| skill.id != deleted.id));
    }
}
