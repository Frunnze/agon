import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/screens/workflows.dart';

import '../../support/random_inputs.dart';

void main() {
  test('test_describe_availability_property_skips_deleted_workspaces', () {
    final Random random = seededRandom(7401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkspaceId> listed = <WorkspaceId>[];
      final List<String> expectedNames = <String>[];
      final int listedCount = random.nextInt(5);
      for (int index = 0; index < listedCount; index += 1) {
        final bool isDeleted = random.nextBool();
        if (isDeleted) {
          listed.add(WorkspaceId('deleted-${random.nextInt(1000)}'));
          continue;
        }
        final Workspace workspace = pickOne(random, galleryWorkspaces);
        listed.add(workspace.id);
        expectedNames.add(workspace.name);
      }

      final String text = describeAvailability(
        OnlyWorkspaces(listed),
        galleryWorkspaces,
      );

      if (expectedNames.isEmpty) {
        expect(text, 'No workspace');
      } else {
        expect(text, expectedNames.join(', '));
      }
    }
  });
}
