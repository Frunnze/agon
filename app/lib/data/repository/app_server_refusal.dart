final class AppServerRefusal extends StateError {
  AppServerRefusal({required this.status, required String reason})
    : super(reason);

  final int status;

  @override
  String toString() => 'the app server answered $status: $message';
}
