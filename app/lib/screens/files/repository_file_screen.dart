import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/repository/file_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/files/branch_choice.dart';
import 'package:agent_orchestration/screens/files/file_content_view.dart';
import 'package:agent_orchestration/screens/files/file_pickers.dart';
import 'package:agent_orchestration/screens/files/file_text.dart';
import 'package:agent_orchestration/screens/files/file_tree_controller.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/screens/files/files_page_parts.dart';
import 'package:agent_orchestration/screens/files/path_breadcrumb.dart';
import 'package:agent_orchestration/screens/files/repository_file_paths.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';

const String copyPathLabel = 'Copy path';

class RepositoryFileScreen extends StatefulWidget {
  const RepositoryFileScreen({
    required this.route,
    required this.projectRepository,
    required this.fileRepository,
    required this.navigation,
    super.key,
  });

  final RepositoryFileRoute route;
  final ProjectRepository projectRepository;
  final FileRepository fileRepository;
  final AppNavigation navigation;

  @override
  State<RepositoryFileScreen> createState() => _RepositoryFileScreenState();
}

class _RepositoryFileScreenState extends State<RepositoryFileScreen> {
  late final FileTreeController _tree = FileTreeController(
    fileRepository: widget.fileRepository,
    location: widget.route.location,
  );
  RepositoryFile? _file;
  String? _problem;
  bool _isTreeRequested = false;

  @override
  void initState() {
    super.initState();
    unawaited(_readFile());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isTreeRequested || !LayoutSize.of(context).isLarge) {
      return;
    }
    _isTreeRequested = true;
    unawaited(_tree.revealFolders(listAncestorFolders(widget.route.path)));
  }

  @override
  void dispose() {
    _tree.dispose();
    super.dispose();
  }

  Future<void> _readFile() async {
    try {
      final RepositoryFile file = await widget.fileRepository.readFile(
        location: widget.route.location,
        path: widget.route.path,
      );
      if (mounted) {
        setState(() => _file = file);
      }
    } on Object catch (problem) {
      final String? explanation = describeProblemForPeople(problem);
      if (explanation == null) {
        rethrow;
      }
      if (mounted) {
        setState(() => _problem = explanation);
      }
    }
  }

  void _returnToFiles() {
    widget.navigation.returnTo(widget.route.filesRoute);
  }

  void _showOtherFiles(ProjectFilesRoute filesRoute) {
    _returnToFiles();
    widget.navigation.replaceRoute(filesRoute);
  }

  void _chooseRepository(String address) {
    _showOtherFiles(
      ProjectFilesRoute(
        projectId: widget.route.filesRoute.projectId,
        repositoryAddress: address,
      ),
    );
  }

  void _chooseBranch(String branch) {
    _showOtherFiles(
      ProjectFilesRoute(
        projectId: widget.route.filesRoute.projectId,
        repositoryAddress: widget.route.filesRoute.repositoryAddress,
        branch: branch,
        preferredRunnerId: widget.route.source.runnerId,
      ),
    );
  }

  void _openFile(String path) {
    final RepositoryFileRoute route = widget.route;
    widget.navigation.replaceRoute(
      RepositoryFileRoute(
        filesRoute: route.filesRoute,
        source: route.source,
        branch: route.branch,
        path: path,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final RepositoryFileRoute route = widget.route;
    final String repositoryPath = describeRepositoryPath(
      route.filesRoute.repositoryAddress,
    );
    final RepositoryFile? file = _file;
    final String? problem = _problem;

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: fileNameOf(route.path),
          summary: file == null
              ? <TextSegment>[TextSegment.monospace(route.branch)]
              : describeFileSummary(branch: route.branch, file: file),
          breadcrumb: PathBreadcrumb(
            labels: describeBreadcrumb(repositoryPath, route.path),
            onPressed: _returnToFiles,
          ),
          actions: <Widget>[
            AppButton.secondary(
              label: copyPathLabel,
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: route.path)),
            ),
          ],
        ),
        if (problem != null) FilesProblem(text: problem),
        _buildBody(repositoryPath, file),
      ],
    );
  }

  Widget _buildBody(String repositoryPath, RepositoryFile? file) {
    final Widget content = file == null
        ? const SizedBox.shrink()
        : FileContentView(file: file, repositoryPath: repositoryPath);
    if (!LayoutSize.of(context).isLarge) {
      return content;
    }

    return SplitLayout(start: _buildTreeSection(), end: content);
  }

  Widget _buildTreeSection() {
    final RepositoryFileRoute route = widget.route;
    final Project project = widget.projectRepository.findProject(
      route.filesRoute.projectId,
    );

    return FileTreeSection(
      repositoryPicker: RepositoryPicker(
        repositories: project.repositories,
        chosenAddress: route.filesRoute.repositoryAddress,
        onChosen: _chooseRepository,
      ),
      branchPicker: BranchPicker(
        entries: buildBranchEntries(route.source),
        chosenBranch: route.branch,
        onChosen: _chooseBranch,
      ),
      runnerName: route.source.runnerName,
      treeView: FileTreeView(
        controller: _tree,
        currentPath: route.path,
        onOpenFile: _openFile,
      ),
    );
  }
}
