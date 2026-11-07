typedef RefusalTest = bool Function(Object error);

bool refusesWithStateError(Object error) => error is StateError;

bool _reportAccepted(Object? outcome) => false;

bool _reportRefused(Object error) => true;

Future<bool> isRefused(
  Future<Object?> Function() step, {
  required RefusalTest isRefusal,
}) {
  final Future<bool> accepted = step().then(_reportAccepted);
  return accepted.catchError(_reportRefused, test: isRefusal);
}
