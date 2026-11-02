import 'dart:math';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';

import 'sample_records.dart';

final ScopeCatalog galleryCatalog = ScopeCatalog(
  workspaces: galleryWorkspaces,
  projects: galleryProjects,
);

const List<WorkspaceId> sampleWorkspaceIds = <WorkspaceId>[
  GalleryWorkspaceIds.acme,
  GalleryWorkspaceIds.personal,
];

List<T> pickSome<T>(Random random, List<T> choices) {
  final List<T> picked = <T>[];
  for (final T choice in choices) {
    if (random.nextBool()) {
      picked.add(choice);
    }
  }
  return picked;
}

WorkspaceScope randomWorkspaceScope(Random random) {
  if (random.nextBool()) {
    return const AllWorkspaces();
  }
  return OnlyWorkspaces(pickSome(random, sampleWorkspaceIds));
}

ProjectScope randomProjectScope(Random random) {
  if (random.nextBool()) {
    return const AllProjects();
  }
  return OnlyProjects(pickSome(random, sampleProjectIds));
}

Scope randomScope(Random random) {
  return Scope(
    workspaces: randomWorkspaceScope(random),
    projects: randomProjectScope(random),
  );
}
