use std::fs;
use std::io;
use std::path::{Path, PathBuf};

use sha2::{Digest, Sha256};

use crate::workspace_mounts::GIT_DIRECTORY_NAME;

const KEPT_ADDRESS_PUNCTUATION: char = '-';
const ADDRESS_ESCAPE_MARKER: char = '_';
const ESCAPED_BYTE_DIGITS: usize = 2;
const HEXADECIMAL_RADIX: u32 = 16;
const LONGEST_FOLDER_NAME_BYTES: usize = 255;
const ADDRESS_HASH_SEPARATOR: char = '.';
const ADDRESS_HASH_LENGTH: usize = 64;
const SHORTENED_NAME_BYTES: usize =
    LONGEST_FOLDER_NAME_BYTES - ADDRESS_HASH_LENGTH - 1;
pub const CLONE_ADDRESS_FILE_NAME: &str = ".clone-address";

#[must_use]
pub fn cached_clone_folder(cache_root: &Path, address: &str) -> PathBuf {
    cache_root.join(encode_clone_folder_name(address))
}

#[must_use]
pub fn encode_clone_folder_name(address: &str) -> String {
    let escaped_name = escape_address(address);
    if escaped_name.len() <= LONGEST_FOLDER_NAME_BYTES {
        return escaped_name;
    }
    let shortened_name = escape_address_start(address);
    let address_hash = hash_address(address);
    format!("{shortened_name}{ADDRESS_HASH_SEPARATOR}{address_hash}")
}

fn escape_address(address: &str) -> String {
    address.bytes().map(encode_address_byte).collect()
}

fn escape_address_start(address: &str) -> String {
    let mut shortened_name = String::new();
    for byte in address.bytes() {
        let encoded_byte = encode_address_byte(byte);
        if shortened_name.len() + encoded_byte.len() > SHORTENED_NAME_BYTES {
            break;
        }
        shortened_name.push_str(&encoded_byte);
    }
    shortened_name
}

fn hash_address(address: &str) -> String {
    let digest = Sha256::digest(address.as_bytes());
    let mut hexadecimal_pairs = Vec::new();
    for byte in &digest {
        hexadecimal_pairs.push(format!("{byte:02x}"));
    }
    hexadecimal_pairs.concat()
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

pub fn record_clone_address(
    cached_clone: &Path,
    address: &str,
) -> io::Result<()> {
    fs::write(cached_clone.join(CLONE_ADDRESS_FILE_NAME), address)
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
        if !folder.join(GIT_DIRECTORY_NAME).is_dir() {
            continue;
        }
        if let Some(address) = read_clone_address(&folder)? {
            addresses.push(address);
        }
    }
    addresses.sort();
    Ok(addresses)
}

fn read_clone_address(folder: &Path) -> io::Result<Option<String>> {
    let Some(folder_name) = folder.file_name().and_then(|name| name.to_str())
    else {
        return Ok(None);
    };
    if let Some(address) = decode_clone_folder_name(folder_name) {
        return Ok(Some(address));
    }

    let recorded_address = read_recorded_address(folder)?;
    let own_address = recorded_address
        .filter(|address| encode_clone_folder_name(address) == folder_name);
    Ok(own_address)
}

fn read_recorded_address(folder: &Path) -> io::Result<Option<String>> {
    match fs::read_to_string(folder.join(CLONE_ADDRESS_FILE_NAME)) {
        Ok(recorded_address) => Ok(Some(recorded_address)),
        Err(problem) if problem.kind() == io::ErrorKind::NotFound => Ok(None),
        Err(problem) => Err(problem),
    }
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
