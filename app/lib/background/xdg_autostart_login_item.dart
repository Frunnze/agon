import 'dart:io';

import 'package:agent_orchestration/background/login_item.dart';
import 'package:agent_orchestration/background/xdg_autostart.dart';

String _describeFileProblem({
  required String problem,
  required FileSystemException failure,
}) {
  final String reason = failure.osError?.message ?? failure.message;
  return '$problem: ${failure.path}: $reason';
}

final class XdgAutostartLoginItem implements LoginItem {
  const XdgAutostartLoginItem({
    required this.environment,
    required this.executablePath,
  });

  final Map<String, String> environment;
  final String executablePath;

  @override
  Future<void> register() async {
    final String entryText = renderAutostartEntry(executablePath);
    final File entry = File(locateAutostartEntry(environment));

    try {
      await entry.parent.create(recursive: true);
      await entry.writeAsString(entryText, flush: true);
    } on FileSystemException catch (failure, stackTrace) {
      final String explanation = _describeFileProblem(
        problem: startAtLoginProblem,
        failure: failure,
      );
      Error.throwWithStackTrace(StateError(explanation), stackTrace);
    }
  }

  @override
  Future<void> unregister() async {
    final File entry = File(locateAutostartEntry(environment));

    try {
      await entry.delete();
    } on PathNotFoundException {
      return;
    } on FileSystemException catch (failure, stackTrace) {
      final String explanation = _describeFileProblem(
        problem: stopStartingAtLoginProblem,
        failure: failure,
      );
      Error.throwWithStackTrace(StateError(explanation), stackTrace);
    }
  }
}
