use orchestration_security::pairing::PairingCode;
use subtle::ConstantTimeEq;

use crate::error::ServerError;

const PAIRING_CODES_PER_SETUP_CODE: usize = 2;
const PAIRING_CODE_SYMBOL_COUNT: usize = 6;
const SETUP_CODE_SYMBOL_COUNT: usize =
    PAIRING_CODES_PER_SETUP_CODE * PAIRING_CODE_SYMBOL_COUNT;
const SYMBOLS_PER_GROUP: usize = 3;
const GROUP_SEPARATOR: char = '-';
const GROUP_SEPARATOR_TEXT: &str = "-";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SetupCode {
    symbols: String,
}

impl SetupCode {
    pub fn generate() -> Result<Self, ServerError> {
        let mut symbols = String::new();
        for _part in 0..PAIRING_CODES_PER_SETUP_CODE {
            let part = PairingCode::generate().map_err(|_| {
                ServerError::Internal("the setup code could not be generated")
            })?;
            symbols.push_str(&String::from(part));
        }
        Ok(Self { symbols })
    }

    pub fn parse(text: &str) -> Option<Self> {
        let characters: Vec<char> = text
            .chars()
            .filter(|character| is_code_character(*character))
            .collect();
        if characters.len() != SETUP_CODE_SYMBOL_COUNT {
            return None;
        }
        let mut symbols = String::new();
        for part in characters.chunks(PAIRING_CODE_SYMBOL_COUNT) {
            let part_text: String = part.iter().collect();
            let code = PairingCode::parse(&part_text).ok()?;
            symbols.push_str(&String::from(code));
        }
        Some(Self { symbols })
    }

    pub fn display(&self) -> String {
        let characters: Vec<char> = self.symbols.chars().collect();
        let groups: Vec<String> = characters
            .chunks(SYMBOLS_PER_GROUP)
            .map(|group| group.iter().collect())
            .collect();
        groups.join(GROUP_SEPARATOR_TEXT)
    }

    pub fn matches(&self, offered: &Self) -> bool {
        let expected_bytes = self.symbols.as_bytes();
        let offered_bytes = offered.symbols.as_bytes();
        expected_bytes.ct_eq(offered_bytes).into()
    }
}

fn is_code_character(character: char) -> bool {
    character != GROUP_SEPARATOR && !character.is_whitespace()
}
