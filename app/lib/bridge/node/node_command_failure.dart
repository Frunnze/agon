final class NodeCommandFailure implements Exception {
  const NodeCommandFailure(this.message);

  final String message;

  @override
  String toString() => 'NodeCommandFailure: $message';
}
