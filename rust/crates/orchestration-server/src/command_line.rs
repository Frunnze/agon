use std::path::PathBuf;

use thiserror::Error;

const LISTEN_OPTION: &str = "--listen";
const DATA_DIRECTORY_OPTION: &str = "--data-directory";
const PUBLIC_ADDRESS_OPTION: &str = "--public-address";
const WEB_ADDRESS_SCHEMES: [&str; 2] = ["http://", "https://"];

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CommandLine {
    pub listen_address: String,
    pub data_directory: PathBuf,
    pub public_address: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Error)]
pub enum CommandLineError {
    #[error("{option} needs a value")]
    MissingValue { option: String },
    #[error("{option} is not a known option")]
    UnknownOption { option: String },
    #[error("{option} is required")]
    MissingOption { option: &'static str },
    #[error("{address} is not an http:// or https:// address")]
    NonWebPublicAddress { address: String },
}

pub fn parse_command_line(
    arguments: impl IntoIterator<Item = String>,
) -> Result<CommandLine, CommandLineError> {
    let mut listen_address = None;
    let mut data_directory = None;
    let mut public_address = None;
    let mut remaining_arguments = arguments.into_iter();
    while let Some(option) = remaining_arguments.next() {
        let Some(value) = remaining_arguments.next() else {
            return Err(CommandLineError::MissingValue { option });
        };
        match option.as_str() {
            LISTEN_OPTION => listen_address = Some(value),
            DATA_DIRECTORY_OPTION => {
                data_directory = Some(PathBuf::from(value));
            }
            PUBLIC_ADDRESS_OPTION => {
                public_address = Some(require_web_address(value)?);
            }
            _ => return Err(CommandLineError::UnknownOption { option }),
        }
    }

    let listen_address =
        listen_address.ok_or(CommandLineError::MissingOption {
            option: LISTEN_OPTION,
        })?;
    let data_directory =
        data_directory.ok_or(CommandLineError::MissingOption {
            option: DATA_DIRECTORY_OPTION,
        })?;
    let public_address =
        public_address.unwrap_or_else(|| listen_address.clone());
    Ok(CommandLine {
        listen_address,
        data_directory,
        public_address,
    })
}

fn require_web_address(address: String) -> Result<String, CommandLineError> {
    for scheme in WEB_ADDRESS_SCHEMES {
        let host = address.strip_prefix(scheme).unwrap_or_default();
        if !host.is_empty() {
            return Ok(address);
        }
    }
    Err(CommandLineError::NonWebPublicAddress { address })
}
