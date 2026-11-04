import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/layout_density.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

typedef _ProtectedFilesChange = Future<Workspace> Function();

const String _sectionTitle = "Files agents can't read";
const String _sectionNote =
    "Agents can't open, edit or search these files. Claude Code refuses "
    'them; in Docker they are hidden; Codex and Gemini CLI run only in '
    'Docker while this list has patterns.';
const String _patternHint = '~/.config/secrets or *.pem';
const String _addLabel = 'Add pattern';
const String _removeLabel = 'Remove';
const String _resetLabel = 'Reset to defaults';
const int _problemLineLimit = 3;

class ProtectedFilesSection extends StatefulWidget {
  const ProtectedFilesSection({required this.workspaceRepository, super.key});

  final WorkspaceRepository workspaceRepository;

  @override
  State<ProtectedFilesSection> createState() => _ProtectedFilesSectionState();
}

class _ProtectedFilesSectionState extends State<ProtectedFilesSection> {
  final TextEditingController _patternController = TextEditingController();
  bool _isSaving = false;
  String? _problem;

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> patterns = _readPatterns();

    return PageSection(
      title: _sectionTitle,
      actions: <Widget>[
        AppButton.secondary(
          label: _resetLabel,
          onPressed: _whenIdle(_resetPatterns),
        ),
      ],
      children: <Widget>[
        const Text(_sectionNote, style: AppTextStyles.bodyMuted),
        if (patterns.isNotEmpty)
          ResponsiveList.plain(
            rows: <ListRowData>[
              for (final String pattern in patterns) _buildPatternRow(pattern),
            ],
          ),
        _buildEntryRow(context),
      ],
    );
  }

  ListRowData _buildPatternRow(String pattern) {
    return ListRowData(
      key: ValueKey<String>(pattern),
      main: ListRowMain.monospace(title: pattern),
      end: AppButton.secondary(
        label: _removeLabel,
        onPressed: _whenIdle(() => _removePattern(pattern)),
      ),
    );
  }

  Widget _buildEntryRow(BuildContext context) {
    final LayoutDensity layoutDensity = LayoutDensity.of(context);
    final double controlHeight = AppSizes.controlHeightFor(layoutDensity);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _patternController,
            autocorrect: false,
            enableSuggestions: false,
            style: AppTextStyles.body.merge(AppTextStyles.monospace),
            onChanged: _clearProblem,
            onSubmitted: _isSaving ? null : _submitTypedPattern,
            decoration: InputDecoration(
              hintText: _patternHint,
              errorText: _problem,
              errorMaxLines: _problemLineLimit,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.space2),
        SizedBox(
          height: controlHeight,
          child: AppButton.secondary(
            label: _addLabel,
            onPressed: _whenIdle(_addTypedPattern),
          ),
        ),
      ],
    );
  }

  List<String> _readPatterns() {
    return widget.workspaceRepository.currentWorkspace().protectedFiles;
  }

  VoidCallback? _whenIdle(VoidCallback action) {
    if (_isSaving) {
      return null;
    }
    return action;
  }

  void _clearProblem(String _) {
    if (_problem != null) {
      setState(() => _problem = null);
    }
  }

  void _submitTypedPattern(String _) => _addTypedPattern();

  void _addTypedPattern() {
    final String pattern = _patternController.text.trim();
    final List<String> patterns = _readPatterns();
    if (pattern.isEmpty || patterns.contains(pattern)) {
      return;
    }

    unawaited(_savePatternsThenClearEntry(<String>[...patterns, pattern]));
  }

  void _removePattern(String removedPattern) {
    final List<String> remainingPatterns = <String>[
      for (final String pattern in _readPatterns())
        if (pattern != removedPattern) pattern,
    ];

    unawaited(_applyChange(() => _savePatterns(remainingPatterns)));
  }

  void _resetPatterns() {
    final Workspace workspace = widget.workspaceRepository.currentWorkspace();

    unawaited(
      _applyChange(
        () => widget.workspaceRepository.resetProtectedFiles(workspace.id),
      ),
    );
  }

  Future<Workspace> _savePatterns(List<String> patterns) {
    final Workspace workspace = widget.workspaceRepository.currentWorkspace();

    return widget.workspaceRepository.saveProtectedFiles(
      workspaceId: workspace.id,
      patterns: patterns,
    );
  }

  Future<void> _savePatternsThenClearEntry(List<String> patterns) async {
    final bool isApplied = await _applyChange(() => _savePatterns(patterns));

    if (isApplied && mounted) {
      _patternController.clear();
    }
  }

  Future<bool> _applyChange(_ProtectedFilesChange change) async {
    setState(() {
      _isSaving = true;
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
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
    return true;
  }
}
