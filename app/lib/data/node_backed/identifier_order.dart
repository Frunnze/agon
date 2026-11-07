List<T> placeInIdentifierOrder<T>(
  List<T> listing, {
  required T record,
  required String Function(T listed) identify,
}) {
  final String identifier = identify(record);
  final List<T> placed = List<T>.of(listing);

  final int storedPosition = listing.indexWhere(
    (T listed) => identify(listed) == identifier,
  );
  if (storedPosition >= 0) {
    placed[storedPosition] = record;
    return List<T>.unmodifiable(placed);
  }

  final int laterPosition = listing.indexWhere(
    (T listed) => identify(listed).compareTo(identifier) > 0,
  );
  if (laterPosition < 0) {
    placed.add(record);
  } else {
    placed.insert(laterPosition, record);
  }
  return List<T>.unmodifiable(placed);
}
