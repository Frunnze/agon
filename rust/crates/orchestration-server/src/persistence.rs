use std::fmt::Display;
use std::fs::{self, OpenOptions};
use std::io::{self, Write};
use std::path::{Path, PathBuf};

use orchestration_security::identity::DeviceIdentity;

use crate::error::ServerError;
use crate::setup_code::SetupCode;
use crate::stored_state::StoredState;
use crate::stored_state_decoding::decode_stored_state;

const STATE_FILE_NAME: &str = "state.json";
const IDENTITY_FILE_NAME: &str = "server-identity.key";
const SETUP_CODE_FILE_NAME: &str = "setup-code";
const TEMPORARY_EXTENSION: &str = "tmp";
#[cfg(unix)]
const PRIVATE_FILE_MODE: u32 = 0o600;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct StateStorage {
    data_directory: PathBuf,
}

impl StateStorage {
    #[must_use]
    pub fn new(data_directory: PathBuf) -> Self {
        Self { data_directory }
    }

    pub fn load_state(&self) -> Result<StoredState, ServerError> {
        let state_path = self.data_directory.join(STATE_FILE_NAME);
        if !state_path.exists() {
            return Ok(StoredState::default());
        }
        let state_bytes = fs::read(&state_path).map_err(storage_error)?;
        decode_stored_state(&state_bytes).map_err(storage_error)
    }

    pub fn save_state(&self, state: &StoredState) -> Result<(), ServerError> {
        let state_bytes = serde_json::to_vec(state).map_err(storage_error)?;
        self.write_atomically(STATE_FILE_NAME, &state_bytes)
    }

    pub fn load_or_create_identity(
        &self,
    ) -> Result<DeviceIdentity, ServerError> {
        let identity_path = self.data_directory.join(IDENTITY_FILE_NAME);
        if identity_path.exists() {
            let secret_bytes =
                fs::read(&identity_path).map_err(storage_error)?;
            return DeviceIdentity::from_secret_bytes(&secret_bytes)
                .map_err(storage_error);
        }
        let identity = DeviceIdentity::generate().map_err(storage_error)?;
        let secret_bytes = identity.secret_bytes();
        self.write_atomically(IDENTITY_FILE_NAME, secret_bytes.as_slice())?;
        Ok(identity)
    }

    pub fn load_setup_code(&self) -> Result<Option<SetupCode>, ServerError> {
        let setup_code_path = self.data_directory.join(SETUP_CODE_FILE_NAME);
        if !setup_code_path.exists() {
            return Ok(None);
        }
        let saved_text =
            fs::read_to_string(&setup_code_path).map_err(storage_error)?;
        let setup_code = SetupCode::parse(&saved_text).ok_or_else(|| {
            ServerError::Storage(
                "the saved setup code is malformed".to_owned(),
            )
        })?;
        Ok(Some(setup_code))
    }

    pub fn save_setup_code(
        &self,
        setup_code: &SetupCode,
    ) -> Result<(), ServerError> {
        let display_text = setup_code.display();
        self.write_atomically(SETUP_CODE_FILE_NAME, display_text.as_bytes())
    }

    pub fn remove_setup_code(&self) -> Result<(), ServerError> {
        let setup_code_path = self.data_directory.join(SETUP_CODE_FILE_NAME);
        match fs::remove_file(&setup_code_path) {
            Err(problem) if problem.kind() == io::ErrorKind::NotFound => {
                Ok(())
            }
            removal => removal.map_err(storage_error),
        }
    }

    fn write_atomically(
        &self,
        file_name: &str,
        contents: &[u8],
    ) -> Result<(), ServerError> {
        fs::create_dir_all(&self.data_directory).map_err(storage_error)?;
        let final_path = self.data_directory.join(file_name);
        let temporary_path = final_path.with_extension(TEMPORARY_EXTENSION);
        write_private_file(&temporary_path, contents)
            .map_err(storage_error)?;
        fs::rename(&temporary_path, &final_path).map_err(storage_error)
    }
}

fn write_private_file(path: &Path, contents: &[u8]) -> io::Result<()> {
    let mut options = OpenOptions::new();
    options.write(true).create(true).truncate(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(PRIVATE_FILE_MODE);
    }
    let mut file = options.open(path)?;
    file.write_all(contents)?;
    file.sync_all()
}

fn storage_error(problem: impl Display) -> ServerError {
    ServerError::Storage(problem.to_string())
}
