sealed class SelectEntry<T> {
  const SelectEntry();
}

final class SelectOption<T> extends SelectEntry<T> {
  const SelectOption({required this.value, required this.label})
    : isEnabled = true;

  const SelectOption.disabled({required this.value, required this.label})
    : isEnabled = false;

  final T value;
  final String label;
  final bool isEnabled;
}

final class SelectGroupHeading<T> extends SelectEntry<T> {
  const SelectGroupHeading(this.label);

  final String label;
}
