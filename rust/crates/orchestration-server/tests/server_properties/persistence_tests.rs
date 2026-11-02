use orchestration_server::StateStorage;
use proptest::prelude::*;

use crate::fixtures::{create_account, create_project};
use crate::operations::{operation_strategy, perform_operation};
use crate::test_client::{TestServer, block_on};

proptest! {
    #![proptest_config(ProptestConfig::with_cases(16))]

    #[test]
    fn test_save_state_property_loaded_state_is_identical(
        operations in proptest::collection::vec(operation_strategy(), 0..10),
    ) {
        let test = TestServer::start();
        block_on(async {
            let account = create_account(&test).await;
            let project = create_project(&test, &account).await;
            for operation in &operations {
                perform_operation(&test, &account, &project, *operation).await;
            }
        });
        let state_in_memory =
            test.server.snapshot_state().expect("the state is readable");
        let storage = StateStorage::new(test.directory.path().to_path_buf());

        let loaded_state = storage.load_state().expect("the state loads");
        let restarted_state = test
            .restart()
            .server
            .snapshot_state()
            .expect("the restarted state is readable");

        prop_assert_eq!(&loaded_state, &state_in_memory);
        prop_assert_eq!(&restarted_state, &state_in_memory);
    }
}

#[test]
fn the_server_keeps_its_identity_across_restarts() {
    let test = TestServer::start();
    let first_identity = test.server.device_id();

    let restarted_identity = test.restart().server.device_id();

    assert_eq!(first_identity, restarted_identity);
}
