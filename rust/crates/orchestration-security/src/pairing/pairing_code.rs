use serde::{Deserialize, Serialize};

use crate::error::SecurityError;
use crate::random_source::random_bytes;

const CODE_LENGTH: usize = 6;
const CODE_GROUP_LENGTH: usize = 3;
const CROCKFORD_ALPHABET: &[u8; 32] = b"0123456789ABCDEFGHJKMNPQRSTVWXYZ";
const CROCKFORD_SYMBOL_MASK: u8 = 0b1_1111;
const GROUP_SEPARATOR: char = '-';

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(try_from = "String", into = "String")]
pub struct PairingCode {
    symbols: String,
}

impl PairingCode {
    pub fn generate() -> Result<Self, SecurityError> {
        let random_symbol_bytes = random_bytes::<CODE_LENGTH>()?;

        let mut symbols = String::new();
        for random_byte in random_symbol_bytes.iter() {
            let alphabet_position = random_byte & CROCKFORD_SYMBOL_MASK;
            let symbol = CROCKFORD_ALPHABET[usize::from(alphabet_position)];
            symbols.push(char::from(symbol));
        }

        Ok(Self { symbols })
    }

    pub fn parse(text: &str) -> Result<Self, SecurityError> {
        let mut symbols = String::new();
        for character in text.chars() {
            if character == GROUP_SEPARATOR || character.is_whitespace() {
                continue;
            }
            let symbol = canonical_symbol(character)
                .ok_or(SecurityError::MalformedPairingCode)?;
            symbols.push(symbol);
        }

        if symbols.len() != CODE_LENGTH {
            return Err(SecurityError::MalformedPairingCode);
        }
        Ok(Self { symbols })
    }

    #[must_use]
    pub fn display(&self) -> String {
        let (first_group, second_group) =
            self.symbols.split_at(CODE_GROUP_LENGTH);
        format!("{first_group}{GROUP_SEPARATOR}{second_group}")
    }
}

impl TryFrom<String> for PairingCode {
    type Error = SecurityError;

    fn try_from(text: String) -> Result<Self, SecurityError> {
        Self::parse(&text)
    }
}

impl From<PairingCode> for String {
    fn from(code: PairingCode) -> Self {
        code.symbols
    }
}

fn canonical_symbol(character: char) -> Option<char> {
    let uppercase = character.to_ascii_uppercase();
    match uppercase {
        'O' => Some('0'),
        'I' | 'L' => Some('1'),
        _ if is_crockford_symbol(uppercase) => Some(uppercase),
        _ => None,
    }
}

fn is_crockford_symbol(character: char) -> bool {
    CROCKFORD_ALPHABET
        .iter()
        .any(|symbol| char::from(*symbol) == character)
}
