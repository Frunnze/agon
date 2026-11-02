import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/repository/file_repository.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';

final class FileTreeController extends ChangeNotifier {
  FileTreeController({required this.fileRepository, required this.location});

  final FileRepository fileRepository;
  final RepositoryBranchLocation location;
  final Map<String, List<RepositoryEntry>> _folderEntries =
      <String, List<RepositoryEntry>>{};
  final Set<String> _expandedFolders = <String>{};
  String? _problem;
  bool _isDisposed = false;

  String? get problem => _problem;

  List<RepositoryEntry>? entriesOf(String folder) => _folderEntries[folder];

  bool isExpanded(String folder) => _expandedFolders.contains(folder);

  Future<void> revealFolders(List<String> folders) async {
    for (final String folder in folders) {
      _expandedFolders.add(folder);
      await _loadFolder(folder);
    }
  }

  Future<void> toggleFolder(String folder) async {
    if (_expandedFolders.remove(folder)) {
      notifyListeners();
      return;
    }

    _expandedFolders.add(folder);
    notifyListeners();
    await _loadFolder(folder);
  }

  Future<void> _loadFolder(String folder) async {
    if (_folderEntries.containsKey(folder)) {
      return;
    }

    try {
      _folderEntries[folder] = await fileRepository.listFolder(
        location: location,
        folder: folder,
      );
    } on Object catch (problem) {
      final String? explanation = describeProblemForPeople(problem);
      if (explanation == null) {
        rethrow;
      }
      _problem = explanation;
    }
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
