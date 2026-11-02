use std::fs;
use std::io;
use std::path::{Path, PathBuf};

use crate::workspace_mounts::GIT_DIRECTORY_NAME;

const KEPT_ADDRESS_PUNCTUATION: char = '-';
const ADDRESS_ESCAPE_MARKER: char = '_';
const ESCAPED_BYTE_DIGITS: usize = 2;
const HEXADECIMAL_RADIX: u32 = 16;

#[must_use]
pub fn cached_clone_folder(cache_root: &Path, address: &str) -> PathBuf {
    cache_root.join(encode_clone_folder_name(address))
}

#[must_use]
pub fn encode_clone_folder_name(address: &str) -> String {
    address.bytes().map(encode_address_byte).collect()
}

#[must_use]
pub fn decode_clone_folder_name(folder_name: &str) -> Option<String> {
    let mut address_bytes = Vec::new();
    let mut characters = folder_name.chars();
    while let Some(character) = characters.next() {
        if is_kept_character(character) {
            address_bytes.push(u8::try_from(character).ok()?);
            continue;
        }
        if character != ADDRESS_ESCAPE_MARKER {
            return None;
        }
        let digits: String =
            characters.by_ref().take(ESCAPED_BYTE_DIGITS).collect();
        address_bytes.push(decode_escaped_byte(&digits)?);
    }
    let address = String::from_utf8(address_bytes).ok()?;
    let is_canonical = encode_clone_folder_name(&address) == folder_name;
    is_canonical.then_some(address)
}

pub fn list_cached_repositories(
    cache_root: &Path,
) -> Result<Vec<String>, io::Error> {
    let folder_entries = match fs::read_dir(cache_root) {
        Ok(folder_entries) => folder_entries,
        Err(problem) if problem.kind() == io::ErrorKind::NotFound => {
            return Ok(Vec::new());
        }
        Err(problem) => return Err(problem),
    };

    let mut addresses = Vec::new();
    for folder_entry in folder_entries {
        let folder = folder_entry?.path();
        let is_clone = folder.join(GIT_DIRECTORY_NAME).is_dir();
        let address = folder
            .file_name()
            .and_then(|name| name.to_str())
            .and_then(decode_clone_folder_name);
        if let (true, Some(address)) = (is_clone, address) {
            addresses.push(address);
        }
    }
    addresses.sort();
    Ok(addresses)
}

fn encode_address_byte(byte: u8) -> String {
    let character = char::from(byte);
    if is_kept_character(character) {
        return character.to_string();
    }
    format!("{ADDRESS_ESCAPE_MARKER}{byte:02x}")
}

fn is_kept_character(character: char) -> bool {
    character.is_ascii_lowercase()
        || character.is_ascii_digit()
        || character == KEPT_ADDRESS_PUNCTUATION
}

fn decode_escaped_byte(digits: &str) -> Option<u8> {
    u8::from_str_radix(digits, HEXADECIMAL_RADIX).ok()
}
