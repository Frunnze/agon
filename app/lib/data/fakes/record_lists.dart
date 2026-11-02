List<T> replaceRecord<T>(
  List<T> records, {
  required bool Function(T record) matches,
  required T replacement,
}) {
  final List<T> replaced = <T>[];

  for (final T record in records) {
    if (matches(record)) {
      replaced.add(replacement);
    } else {
      replaced.add(record);
    }
  }

  return List<T>.unmodifiable(replaced);
}

List<T> prependRecord<T>(List<T> records, T record) {
  return List<T>.unmodifiable(<T>[record, ...records]);
}

List<T> appendRecord<T>(List<T> records, T record) {
  return List<T>.unmodifiable(<T>[...records, record]);
}

List<T> replaceOrAppendRecord<T>(
  List<T> records, {
  required bool Function(T record) matches,
  required T record,
}) {
  final bool isStored = records.any(matches);

  if (isStored) {
    return replaceRecord(records, matches: matches, replacement: record);
  }
  return appendRecord(records, record);
}

List<T> removeRecord<T>(
  List<T> records, {
  required bool Function(T record) matches,
}) {
  final List<T> remaining = <T>[];

  for (final T record in records) {
    if (!matches(record)) {
      remaining.add(record);
    }
  }

  return List<T>.unmodifiable(remaining);
}
