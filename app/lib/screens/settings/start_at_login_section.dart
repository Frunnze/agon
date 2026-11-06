import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

typedef _StartAtLoginChange = Future<void> Function();

const String startAtLoginLabel = 'Start at login';
const String _sectionTitle = 'This computer';
const String _startAtLoginHint =
    'Opens when you log in so this computer can run tasks.';

class StartAtLoginSection extends StatefulWidget {
  const StartAtLoginSection({required this.runnerPresence, super.key});

  final RunnerPresence runnerPresence;

  @override
  State<StartAtLoginSection> createState() => _StartAtLoginSectionState();
}

class _StartAtLoginSectionState extends State<StartAtLoginSection> {
  bool? _isStartAtLoginChosen;
  bool _isChanging = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    unawaited(_readSavedChoice());
  }

  @override
  Widget build(BuildContext context) {
    final bool? isStartAtLoginChosen = _isStartAtLoginChosen;
    if (isStartAtLoginChosen == null) {
      return const SizedBox.shrink();
    }

    final String hint = _problem ?? _startAtLoginHint;
    final ListRowData startAtLoginRow = ListRowData(
      main: ListRowMain(
        title: startAtLoginLabel,
        subtitle: <TextSegment>[TextSegment(hint)],
      ),
      end: SwitchToggle(
        semanticLabel: startAtLoginLabel,
        value: isStartAtLoginChosen,
        onChanged: _chooseSwitchHandler(isStartAtLoginChosen),
      ),
    );

    return PageSection(
      title: _sectionTitle,
      children: <Widget>[
        ResponsiveList.plain(rows: <ListRowData>[startAtLoginRow]),
      ],
    );
  }

  ValueChanged<bool>? _chooseSwitchHandler(bool isStartAtLoginChosen) {
    if (_isChanging) {
      return null;
    }
    if (isStartAtLoginChosen) {
      return _turnStartAtLoginOff;
    }
    return _turnStartAtLoginOn;
  }

  void _turnStartAtLoginOn(bool _) {
    unawaited(_changeStartAtLogin(widget.runnerPresence.startAtLogin));
  }

  void _turnStartAtLoginOff(bool _) {
    unawaited(_changeStartAtLogin(widget.runnerPresence.stopStartingAtLogin));
  }

  Future<void> _changeStartAtLogin(_StartAtLoginChange change) async {
    setState(() {
      _isChanging = true;
      _problem = null;
    });

    try {
      await change();
    } on Object catch (problem) {
      final String? explanation = describeProblemForPeople(problem);
      if (explanation == null) {
        rethrow;
      }
      if (mounted) {
        setState(() => _problem = explanation);
      }
    } finally {
      if (mounted) {
        setState(() => _isChanging = false);
      }
    }

    await _readSavedChoice();
  }

  Future<void> _readSavedChoice() async {
    final bool isStartAtLoginChosen = await widget
        .runnerPresence
        .startAtLoginChoiceStore
        .readIsStartAtLoginChosen();
    if (mounted) {
      setState(() => _isStartAtLoginChosen = isStartAtLoginChosen);
    }
  }
}
