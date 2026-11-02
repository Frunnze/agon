use orchestration_security::pairing::PairingTranscript;

pub(super) fn list_fingerprint_words(
    transcript: &PairingTranscript,
) -> Vec<String> {
    let mut words = Vec::new();
    for word in transcript.fingerprint_words() {
        words.push(word.to_owned());
    }
    words
}
