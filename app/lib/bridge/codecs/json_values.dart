typedef JsonObject = Map<String, Object?>;

typedef JsonValueDecoder<Value> = Value Function(Object? json);

final RegExp _rfc3339Moment = RegExp(
  r'^(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})[Tt]'
  r'(?<hour>\d{2}):(?<minute>\d{2}):(?<second>\d{2})(?:\.\d+)?'
  r'(?:[Zz]|[+-](?<offsetHours>\d{2}):(?<offsetMinutes>\d{2}))$',
);

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
  final RegExpMatch? parts = _rfc3339Moment.firstMatch(text);
  final DateTime? moment = DateTime.tryParse(text);
  if (parts == null || moment == null || !_hasRealCalendarParts(parts)) {
    throw FormatException('expected an RFC 3339 moment, found $text');
  }
  return moment;
}

bool _hasRealCalendarParts(RegExpMatch parts) {
  final int year = int.parse(parts.namedGroup('year')!);
  final int month = int.parse(parts.namedGroup('month')!);
  final int day = int.parse(parts.namedGroup('day')!);
  final int hour = int.parse(parts.namedGroup('hour')!);
  final int minute = int.parse(parts.namedGroup('minute')!);
  final int second = int.parse(parts.namedGroup('second')!);
  final int offsetHours = int.parse(parts.namedGroup('offsetHours') ?? '0');
  final int offsetMinutes = int.parse(
    parts.namedGroup('offsetMinutes') ?? '0',
  );

  final bool isRealMonth = month >= 1 && month <= DateTime.monthsPerYear;
  final int daysInMonth = DateTime.utc(year, month + 1, 0).day;
  final bool isRealDay = day >= 1 && day <= daysInMonth;
  final bool isRealTime =
      hour < Duration.hoursPerDay &&
      minute < Duration.minutesPerHour &&
      second < Duration.secondsPerMinute;
  final bool isRealOffset =
      offsetHours < Duration.hoursPerDay &&
      offsetMinutes < Duration.minutesPerHour;
  return isRealMonth && isRealDay && isRealTime && isRealOffset;
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
