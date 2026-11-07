use std::fmt::Debug;

use proptest::prelude::*;
use serde::Serialize;
use serde::de::DeserializeOwned;
use serde_json::Value;

fn encode(message: &impl Serialize) -> Result<Value, TestCaseError> {
    serde_json::to_value(message)
        .map_err(|error| TestCaseError::fail(error.to_string()))
}

fn is_snake_case(key: &str) -> bool {
    let starts_with_letter = key
        .chars()
        .next()
        .is_some_and(|letter| letter.is_ascii_lowercase());
    let has_only_snake_characters = key.chars().all(|character| {
        character.is_ascii_lowercase()
            || character.is_ascii_digit()
            || character == '_'
    });
    starts_with_letter && has_only_snake_characters
}

fn collect_object_keys(encoded: &Value) -> Vec<String> {
    let mut keys = Vec::new();
    match encoded {
        Value::Object(fields) => {
            for (key, field) in fields {
                keys.push(key.clone());
                keys.extend(collect_object_keys(field));
            }
        }
        Value::Array(items) => {
            for item in items {
                keys.extend(collect_object_keys(item));
            }
        }
        _ => {}
    }
    keys
}

pub fn check_round_trip<Message>(
    message: &Message,
) -> Result<(), TestCaseError>
where
    Message: Serialize + DeserializeOwned + PartialEq + Debug,
{
    let encoded = serde_json::to_string(message)
        .map_err(|error| TestCaseError::fail(error.to_string()))?;
    let decoded: Message = serde_json::from_str(&encoded)
        .map_err(|error| TestCaseError::fail(error.to_string()))?;

    prop_assert_eq!(&decoded, message);
    Ok(())
}

pub fn check_snake_case_keys(
    message: &impl Serialize,
) -> Result<(), TestCaseError> {
    let keys = collect_object_keys(&encode(message)?);

    for key in keys {
        prop_assert!(is_snake_case(&key), "{key:?} is not snake_case");
    }
    Ok(())
}

pub fn check_required_fields<Message>(
    message: &Message,
    optional_fields: &[&str],
) -> Result<(), TestCaseError>
where
    Message: Serialize + DeserializeOwned,
{
    let encoded = encode(message)?;
    let Value::Object(fields) = &encoded else {
        return Err(TestCaseError::fail("a message is a JSON object"));
    };

    for key in fields.keys() {
        let mut without_field = fields.clone();
        without_field.remove(key);
        let decoded =
            serde_json::from_value::<Message>(Value::Object(without_field));
        let is_optional = optional_fields.contains(&key.as_str());
        prop_assert_eq!(decoded.is_ok(), is_optional, "field {:?}", key);
    }
    Ok(())
}
