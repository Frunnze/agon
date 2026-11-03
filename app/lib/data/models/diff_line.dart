enum DiffLineChange { unchanged, added, removed }

final class DiffLine {
  const DiffLine({required this.change, required this.text});

  final DiffLineChange change;
  final String text;
}
