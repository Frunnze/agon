use chrono::DateTime;
use orchestration_core::library::SkillChangeOrigin;
use orchestration_core::skill_history::record_skill_change;
use orchestration_node::content_sealing::{open_skill, seal_skill};
use proptest::prelude::*;

use crate::content_sealing_properties::{
    hides_every_secret, sample_workspace,
};
use crate::support::entity_strategies::{
    sample_keyring, sample_skill, secret_texts_strategy,
};
use crate::support::test_device::fail;

proptest! {
    #[test]
    fn test_seal_skill_property_hides_every_replaced_version(
        versions in secret_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(sample_workspace()).map_err(fail)?;
        let mut skill = sample_skill("First version");
        for version in &versions {
            let origin = SkillChangeOrigin::PersonEdit;
            let moment = DateTime::UNIX_EPOCH;
            skill = record_skill_change(&skill, version, origin, moment);
        }

        let sealed_skill = seal_skill(&workspace_key, &skill).map_err(fail)?;

        prop_assert!(hides_every_secret(&sealed_skill, &versions)?);
        let opened_skill = open_skill(&keyring, &sealed_skill).map_err(fail)?;
        prop_assert_eq!(opened_skill, skill);
    }
}
