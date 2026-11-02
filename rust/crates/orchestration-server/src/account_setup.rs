use std::sync::MutexGuard;

use crate::error::ServerError;
use crate::persistence::StateStorage;
use crate::setup_code::SetupCode;
use crate::stored_state::StoredState;

const WRONG_SETUP_CODE: &str = "the setup code is wrong";

#[derive(Debug)]
pub struct PreparedSetup {
    pub setup_code: Option<SetupCode>,
    pub newly_issued: Option<String>,
}

#[derive(Debug)]
pub struct SetupCodeClaim<'server> {
    setup_code: MutexGuard<'server, Option<SetupCode>>,
    storage: &'server StateStorage,
}

impl<'server> SetupCodeClaim<'server> {
    pub fn verify(
        setup_code: MutexGuard<'server, Option<SetupCode>>,
        storage: &'server StateStorage,
        offered_text: &str,
    ) -> Result<Self, ServerError> {
        let expected = setup_code
            .as_ref()
            .ok_or(ServerError::Forbidden("account setup is closed"))?;
        let offered = SetupCode::parse(offered_text)
            .ok_or(ServerError::Forbidden(WRONG_SETUP_CODE))?;
        if !expected.matches(&offered) {
            return Err(ServerError::Forbidden(WRONG_SETUP_CODE));
        }
        Ok(Self {
            setup_code,
            storage,
        })
    }

    pub fn invalidate(mut self) -> Result<(), ServerError> {
        *self.setup_code = None;
        self.storage.remove_setup_code()
    }
}

pub fn prepare_setup_code(
    storage: &StateStorage,
    state: &StoredState,
) -> Result<PreparedSetup, ServerError> {
    if !state.devices.is_empty() {
        storage.remove_setup_code()?;
        return Ok(PreparedSetup {
            setup_code: None,
            newly_issued: None,
        });
    }
    if let Some(saved_code) = storage.load_setup_code()? {
        return Ok(PreparedSetup {
            setup_code: Some(saved_code),
            newly_issued: None,
        });
    }

    let issued_code = SetupCode::generate()?;
    storage.save_setup_code(&issued_code)?;
    Ok(PreparedSetup {
        newly_issued: Some(issued_code.display()),
        setup_code: Some(issued_code),
    })
}
