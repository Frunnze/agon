import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/files/file_sizes.dart';
import 'package:agent_orchestration/screens/files/file_tree_controller.dart';
import 'package:agent_orchestration/screens/files/repository_file_paths.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/layout_density.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';

const String _rootFolder = '';
const double _expandedTurns = 0.25;
const double _collapsedTurns = 0;

final class _TreeLine {
  const _TreeLine({
    required this.entry,
    required this.path,
    required this.depth,
  });

  final RepositoryEntry entry;
  final String path;
  final int depth;
}

class FileTreeView extends StatelessWidget {
  const FileTreeView({
    required this.controller,
    required this.currentPath,
    required this.onOpenFile,
    super.key,
  });

  final FileTreeController controller;
  final String? currentPath;
  final ValueChanged<String> onOpenFile;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: controller, builder: _buildTree);
  }

  Widget _buildTree(BuildContext context, Widget? _) {
    final List<_TreeLine> lines = <_TreeLine>[];
    _collectLines(_rootFolder, 0, lines);

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final _TreeLine line in lines) _buildRow(line),
        ],
      ),
    );
  }

  void _collectLines(String folder, int depth, List<_TreeLine> lines) {
    final List<RepositoryEntry> entries =
        controller.entriesOf(folder) ?? const <RepositoryEntry>[];

    for (final RepositoryEntry entry in entries) {
      final String path = joinRepositoryPath(folder, entry.name);
      lines.add(_TreeLine(entry: entry, path: path, depth: depth));
      final bool isOpenFolder =
          entry.kind == RepositoryEntryKind.folder &&
          controller.isExpanded(path);
      if (isOpenFolder) {
        _collectLines(path, depth + 1, lines);
      }
    }
  }

  Widget _buildRow(_TreeLine line) {
    final bool isFolder = line.entry.kind == RepositoryEntryKind.folder;
    final bool isCurrent = line.path == currentPath;

    return FileTreeRow(
      key: ValueKey<String>(line.path),
      name: line.entry.name,
      size: line.entry.size,
      depth: line.depth,
      folderState: isFolder
          ? _describeFolderState(line.path)
          : FolderState.notAFolder,
      emphasis: isCurrent ? RowEmphasis.current : RowEmphasis.normal,
      onTap: isFolder
          ? () => controller.toggleFolder(line.path)
          : () => onOpenFile(line.path),
    );
  }

  FolderState _describeFolderState(String path) {
    if (controller.isExpanded(path)) {
      return FolderState.expanded;
    }
    return FolderState.collapsed;
  }
}

enum FolderState { notAFolder, collapsed, expanded }

class FileTreeRow extends StatelessWidget {
  const FileTreeRow({
    required this.name,
    required this.size,
    required this.depth,
    required this.folderState,
    required this.emphasis,
    required this.onTap,
    super.key,
  });

  final String name;
  final int? size;
  final int depth;
  final FolderState folderState;
  final RowEmphasis emphasis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final LayoutDensity layoutDensity = LayoutDensity.of(context);
    final double controlHeight = AppSizes.controlHeightFor(layoutDensity);

    final int? fileSize = size;
    final double indent = AppSpacing.space3 + depth * AppSpacing.space5;

    return Semantics(
      button: true,
      expanded: _describeExpandedState(),
      child: InkWell(
        onTap: onTap,
        mouseCursor: WidgetStateMouseCursor.clickable,
        child: Container(
          constraints: BoxConstraints(minHeight: controlHeight),
          decoration: buildRowDecoration(emphasis),
          padding: EdgeInsets.fromLTRB(
            indent,
            AppSpacing.space2,
            AppSpacing.space3,
            AppSpacing.space2,
          ),
          child: Row(
            children: <Widget>[
              _buildMarker(),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                child: Text(
                  name,
                  style: AppTextStyles.body.merge(AppTextStyles.monospace),
                ),
              ),
              if (fileSize != null) const SizedBox(width: AppSpacing.space2),
              if (fileSize != null)
                Text(
                  describeFileSize(fileSize),
                  style: AppTextStyles.smallMuted.copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool? _describeExpandedState() {
    return switch (folderState) {
      FolderState.notAFolder => null,
      FolderState.collapsed => false,
      FolderState.expanded => true,
    };
  }

  Widget _buildMarker() {
    if (folderState == FolderState.notAFolder) {
      return const SizedBox(width: AppSizes.iconSmall);
    }

    return AnimatedRotation(
      turns: folderState == FolderState.expanded
          ? _expandedTurns
          : _collapsedTurns,
      duration: AppDurations.micro,
      child: const AppIcon(
        AppIconKind.chevronRight,
        size: AppIconSize.small,
        color: AppColors.inkMuted,
      ),
    );
  }
}
