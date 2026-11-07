const String noAccountFailureKind = 'no_account';

final class NodeCommandFailure implements Exception {
  const NodeCommandFailure(this.message, {this.kind});

  final String message;
  final String? kind;

  @override
  String toString() => 'NodeCommandFailure: $message';
}
