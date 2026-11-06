import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/xdg_autostart.dart';

import '../../support/desktop_entry_reading.dart';

const String _executablePathArgument = 'executablePath';
const String _temporaryFolderPrefix = 'autostart_';

Matcher throwsArgumentErrorAbout(String executablePath) {
  return throwsA(
    isA<ArgumentError>()
        .having(
          (ArgumentError error) => error.name,
          'name',
          _executablePathArgument,
        )
        .having(
          (ArgumentError error) => error.invalidValue,
          'invalidValue',
          executablePath,
        ),
  );
}

List<String> readExecArguments(String executablePath) {
  final String entryText = renderAutostartEntry(executablePath);
  final String execValue = readDesktopEntryValue(entryText, 'Exec');
  return parseDesktopEntryExec(execValue);
}

Directory createTemporaryFolder() {
  final Directory folder = Directory.systemTemp.createTempSync(
    _temporaryFolderPrefix,
  );
  addTearDown(() => folder.deleteSync(recursive: true));
  return folder;
}
