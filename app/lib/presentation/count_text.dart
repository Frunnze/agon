String describeCount(
  int count, {
  required String singular,
  required String plural,
}) {
  if (count == 1) {
    return '1 $singular';
  }
  return '$count $plural';
}
