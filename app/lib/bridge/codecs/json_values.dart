typedef JsonObject = Map<String, Object?>;

typedef JsonValueDecoder<Value> = Value Function(Object? json);

abstract interface class JsonEncodable {
  Object? toJson();
}

abstract interface class WireNamed {
  String get wireName;
}

JsonObject decodeObject(Object? json) {
  if (json is Map<String, Object?>) {
    return json;
  }
  throw FormatException('expected a JSON object, found $json');
}

String decodeText(Object? json) {
  if (json is String) {
    return json;
  }
  throw FormatException('expected text, found $json');
}

int decodeInteger(Object? json) {
  if (json is int) {
    return json;
  }
  throw FormatException('expected a whole number, found $json');
}

double decodeNumber(Object? json) {
  if (json is num) {
    return json.toDouble();
  }
  throw FormatException('expected a number, found $json');
}

bool decodeFlag(Object? json) {
  if (json is bool) {
    return json;
  }
  throw FormatException('expected true or false, found $json');
}

DateTime decodeMoment(Object? json) {
  final String text = decodeText(json);
  final DateTime? moment = DateTime.tryParse(text);
  if (moment == null) {
    throw FormatException('expected an RFC 3339 moment, found $text');
  }
  return moment.toUtc();
}

String encodeMoment(DateTime moment) {
  return moment.toUtc().toIso8601String();
}

String? encodeOptionalMoment(DateTime? moment) {
  if (moment == null) {
    return null;
  }
  return encodeMoment(moment);
}

void decodeNothing(Object? json) {
  if (json != null) {
    throw FormatException('expected null, found $json');
  }
}

List<Value> decodeList<Value>(
  Object? json,
  JsonValueDecoder<Value> decodeElement,
) {
  if (json is! List<Object?>) {
    throw FormatException('expected a JSON list, found $json');
  }
  final List<Value> values = <Value>[];
  for (final Object? element in json) {
    values.add(decodeElement(element));
  }
  return List<Value>.unmodifiable(values);
}

List<Object?> encodeList(List<JsonEncodable> values) {
  final List<Object?> encodedValues = <Object?>[];
  for (final JsonEncodable value in values) {
    encodedValues.add(value.toJson());
  }
  return encodedValues;
}

Choice decodeWireName<Choice extends WireNamed>(
  List<Choice> choices,
  Object? json,
) {
  final String wireName = decodeText(json);
  for (final Choice choice in choices) {
    if (choice.wireName == wireName) {
      return choice;
    }
  }
  throw FormatException('unknown value $wireName');
}

Value readField<Value>(
  JsonObject fields,
  String field,
  JsonValueDecoder<Value> decodeValue,
) {
  final Object? json = _readPresentField(fields, field);
  return decodeValue(json);
}

Value? readOptionalField<Value>(
  JsonObject fields,
  String field,
  JsonValueDecoder<Value> decodeValue,
) {
  final Object? json = fields[field];
  if (json == null) {
    return null;
  }
  return decodeValue(json);
}

List<Value> readListField<Value>(
  JsonObject fields,
  String field,
  JsonValueDecoder<Value> decodeElement,
) {
  final Object? json = _readPresentField(fields, field);
  return decodeList(json, decodeElement);
}

List<Value> readListFieldWhenPresent<Value>(
  JsonObject fields,
  String field,
  JsonValueDecoder<Value> decodeElement,
) {
  if (!fields.containsKey(field)) {
    return List<Value>.unmodifiable(<Value>[]);
  }
  return decodeList(fields[field], decodeElement);
}

Object? _readPresentField(JsonObject fields, String field) {
  if (!fields.containsKey(field)) {
    throw FormatException('the field $field is missing');
  }
  return fields[field];
}
