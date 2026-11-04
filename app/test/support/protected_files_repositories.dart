import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

final class RefusingProtectedFilesRepository extends Fake
    implements WorkspaceRepository {
  RefusingProtectedFilesRepository({
    required FakeWorkspaceRepository inner,
    required String refusal,
  }) : _inner = inner,
       _refusal = refusal;

  final FakeWorkspaceRepository _inner;
  final String _refusal;

  @override
  Workspace currentWorkspace() => _inner.currentWorkspace();

  @override
  Future<Workspace> saveProtectedFiles({
    required WorkspaceId workspaceId,
    required List<String> patterns,
  }) async {
    throw StateError(_refusal);
  }

  @override
  Future<Workspace> resetProtectedFiles(WorkspaceId workspaceId) async {
    throw StateError(_refusal);
  }
}
