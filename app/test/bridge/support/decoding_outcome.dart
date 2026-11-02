enum DecodingOutcome { decoded, rejectedAsMalformed }

DecodingOutcome attemptDecoding(void Function() decode) {
  try {
    decode();
  } on FormatException {
    return DecodingOutcome.rejectedAsMalformed;
  }
  return DecodingOutcome.decoded;
}
