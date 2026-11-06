import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/xdg_autostart.dart';
import 'package:agent_orchestration/product_name.dart';

import '../support/desktop_entry_reading.dart';
import '../support/random_inputs.dart';
import 'support/autostart_expectations.dart';
import 'support/hostile_paths.dart';

const String _posixShell = '/bin/sh';
const String _shellArgumentSeparator = '\u0000';

String _readAsShellCommandLine(String executablePath) {
  final String entryText = renderAutostartEntry(executablePath);
  final String execValue = readDesktopEntryValue(entryText, 'Exec');
  final String withoutStringEscapes = execValue.replaceAll(r'\\', r'\');
  return withoutStringEscapes.replaceAll('%%', '%');
}

Future<List<String>> _readWithPosixShell(List<String> commandLines) async {
  final String script = "printf '%s\\0' ${commandLines.join(' ')}";
  final ProcessResult shellRun = await Process.run(
    _posixShell,
    <String>['-c', script],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (shellRun.exitCode != 0) {
    fail('the shell refused the command lines: ${shellRun.stderr}');
  }

  final String shellOutput = '${shellRun.stdout}';
  final List<String> arguments = shellOutput.split(_shellArgumentSeparator);
  return arguments.sublist(0, arguments.length - 1);
}

void main() {
  test('test_quote_argument_property_hostile_paths_stay_one_argument', () {
    final Random random = seededRandom(48507);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String executablePath = randomHostileAbsolutePath(random);

      expect(readExecArguments(executablePath), <String>[executablePath]);
    }
  });

  test(
    'test_quote_argument_property_a_posix_shell_reads_the_same_path',
    () async {
      final Random random = seededRandom(48508);
      final List<String> executablePaths = <String>[];
      final List<String> commandLines = <String>[];

      for (int i = 0; i < propertyIterations; i += 1) {
        final String executablePath = randomHostileAbsolutePath(random);
        executablePaths.add(executablePath);
        commandLines.add(_readAsShellCommandLine(executablePath));
      }

      expect(await _readWithPosixShell(commandLines), executablePaths);
    },
  );

  test('test_quote_argument_property_exec_line_keeps_the_entry_shape', () {
    final Random random = seededRandom(48509);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String executablePath = randomHostileAbsolutePath(random);
      final String entryText = renderAutostartEntry(executablePath);

      expect(entryText.split('\n'), <Object>[
        '[Desktop Entry]',
        'Type=Application',
        'Name=$productName',
        allOf(startsWith('Exec="'), endsWith('"')),
        '',
      ]);
    }
  });
}
