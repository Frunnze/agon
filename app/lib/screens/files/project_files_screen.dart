import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/repository/file_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/files/branch_choice.dart';
import 'package:agent_orchestration/screens/files/file_pickers.dart';
import 'package:agent_orchestration/screens/files/file_tree_controller.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/screens/files/files_page_parts.dart';
import 'package:agent_orchestration/screens/files/no_runner_view.dart';
import 'package:agent_orchestration/screens/files/readme_section.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';

const String _rootFolder = '';
const String _readmeName = 'readme.md';

class ProjectFilesScreen extends StatefulWidget {
  const ProjectFilesScreen({
    required this.route,
    required this.projectRepository,
    required this.fileRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final ProjectFilesRoute route;
  final ProjectRepository projectRepository;
  final FileRepository fileRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  State<ProjectFilesScreen> createState() => _ProjectFilesScreenState();
}

class _ProjectFilesScreenState extends State<ProjectFilesScreen> {
  RepositoryFileSource? _source;
  String? _branch;
  FileTreeController? _tree;
  RepositoryFile? _readme;
  String? _problem;

  @override
  void initState() {
    super.initState();
    unawaited(_openRepository());
  }

  @override
  void dispose() {
    _tree?.dispose();
    super.dispose();
  }

  Future<void> _openRepository() async {
    final ProjectFilesRoute route = widget.route;
    final RepositoryFileSource? source = await _attempt(
      () => widget.fileRepository.openRepository(
        projectId: route.projectId,
        repositoryAddress: route.repositoryAddress,
      ),
    );
    if (!mounted || source == null) {
      return;
    }
    if (source is! FilesFromRunner) {
      setState(() => _source = source);
      return;
    }

    final String? branch = chooseInitialBranch(
      source: source,
      requestedBranch: route.branch,
      defaultBranch: _findRepository().defaultBranch,
    );
    final FileTreeController? tree = branch == null
        ? null
        : FileTreeController(
            fileRepository: widget.fileRepository,
            location: _locate(source, branch),
          );
    setState(() {
      _source = source;
      _branch = branch;
      _tree = tree;
    });
    if (tree != null) {
      await tree.revealFolders(const <String>[_rootFolder]);
      await _readReadme(tree);
    }
  }

  Future<void> _readReadme(FileTreeController tree) async {
    final List<RepositoryEntry> root =
        tree.entriesOf(_rootFolder) ?? const <RepositoryEntry>[];
    for (final RepositoryEntry entry in root) {
      final bool isReadme =
          entry.kind == RepositoryEntryKind.file &&
          entry.name.toLowerCase() == _readmeName;
      if (isReadme) {
        final RepositoryFile? readme = await _attempt(
          () => widget.fileRepository.readFile(
            location: tree.location,
            path: entry.name,
          ),
        );
        if (mounted) {
          setState(() => _readme = readme);
        }
        return;
      }
    }
  }

  Future<Answer?> _attempt<Answer>(Future<Answer> Function() question) async {
    try {
      return await question();
    } on Object catch (problem) {
      final String? explanation = describeProblemForPeople(problem);
      if (explanation == null) {
        rethrow;
      }
      if (mounted) {
        setState(() => _problem = explanation);
      }
      return null;
    }
  }

  void _tryAgain() {
    _tree?.dispose();
    setState(() {
      _source = null;
      _branch = null;
      _tree = null;
      _readme = null;
      _problem = null;
    });
    unawaited(_openRepository());
  }

  Project _findProject() {
    return widget.projectRepository.findProject(widget.route.projectId);
  }

  Repository _findRepository() {
    final String address = widget.route.repositoryAddress;
    for (final Repository repository in _findProject().repositories) {
      if (repository.address == address) {
        return repository;
      }
    }
    throw StateError('the project has no repository $address');
  }

  RepositoryBranchLocation _locate(FilesFromRunner source, String branch) {
    return RepositoryBranchLocation(
      projectId: widget.route.projectId,
      repositoryAddress: widget.route.repositoryAddress,
      runnerId: source.runnerId,
      branch: branch,
    );
  }

  void _chooseRepository(String address) {
    widget.navigation.replaceRoute(
      ProjectFilesRoute(
        projectId: widget.route.projectId,
        repositoryAddress: address,
      ),
    );
  }

  void _chooseBranch(String branch) {
    widget.navigation.replaceRoute(
      ProjectFilesRoute(
        projectId: widget.route.projectId,
        repositoryAddress: widget.route.repositoryAddress,
        branch: branch,
      ),
    );
  }

  void _openFile(FilesFromRunner source, String branch, String path) {
    widget.navigation.openRoute(
      RepositoryFileRoute(
        filesRoute: widget.route,
        source: source,
        branch: branch,
        path: path,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Project project = _findProject();
    final String? problem = _problem;

    return AppPage(
      children: <Widget>[
        buildFilesPageHeader(
          projectName: project.name,
          onBack: () => widget.navigation.returnTo(ProjectRoute(project.id)),
        ),
        if (problem != null) FilesProblem(text: problem),
        ..._buildBody(project),
      ],
    );
  }

  List<Widget> _buildBody(Project project) {
    final RepositoryFileSource? source = _source;
    final Widget repositoryPicker = RepositoryPicker(
      repositories: project.repositories,
      chosenAddress: widget.route.repositoryAddress,
      onChosen: _chooseRepository,
    );

    switch (source) {
      case null:
        return <Widget>[
          FilePickers(repository: repositoryPicker, branch: null),
        ];
      case FilesWithoutRunner(:final List<RepositoryHolder> holders):
        return <Widget>[
          FilePickers(repository: repositoryPicker, branch: null),
          NoRunnerView(
            holders: holders,
            repositoryPath: describeRepositoryPath(
              widget.route.repositoryAddress,
            ),
            now: widget.clock.now(),
            onTryAgain: _tryAgain,
            onSeeRunners: () =>
                widget.navigation.openRoute(const RunnersSettingsRoute()),
          ),
        ];
      case FilesFromRunner():
        return <Widget>[_buildBrowser(source, repositoryPicker)];
    }
  }

  Widget _buildBrowser(FilesFromRunner source, Widget repositoryPicker) {
    final String? branch = _branch;
    final FileTreeController? tree = _tree;
    final Widget treeSection = FileTreeSection(
      repositoryPicker: repositoryPicker,
      branchPicker: branch == null
          ? null
          : BranchPicker(
              entries: buildBranchEntries(source),
              chosenBranch: branch,
              onChosen: _chooseBranch,
            ),
      runnerName: source.runnerName,
      treeView: tree == null
          ? null
          : FileTreeView(
              controller: tree,
              currentPath: null,
              onOpenFile: (String path) =>
                  _openFile(source, tree.location.branch, path),
            ),
    );
    if (!LayoutSize.of(context).isLarge) {
      return treeSection;
    }

    final RepositoryFile? readme = _readme;
    return SplitLayout(
      start: treeSection,
      end: readme == null
          ? const SizedBox.shrink()
          : ReadmeSection(
              readme: readme,
              repositoryPath: describeRepositoryPath(
                widget.route.repositoryAddress,
              ),
            ),
    );
  }
}
