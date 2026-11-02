import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';

abstract interface class ProjectRepository implements Listenable {
  List<Project> listProjects(WorkspaceId workspaceId);

  Project findProject(ProjectId projectId);

  Future<Project> createProject(ProjectDraft draft);

  Future<Project> addRepository(ProjectId projectId, Repository repository);

  Future<Project> removeRepository(ProjectId projectId, String address);

  Future<void> deleteProject(ProjectId projectId);
}
