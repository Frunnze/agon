import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../support/random_inputs.dart';

void main() {
  test('test_with_approval_policy_property_changes_only_the_policy', () {
    final Random random = seededRandom(9861);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace workspace = pickOne(random, galleryWorkspaces);
      final ApprovalPolicy chosen = pickOne(random, ApprovalPolicy.values);

      final Workspace changed = workspace.withApprovalPolicy(chosen);

      expect(changed.approvalPolicy, chosen);
      expect(changed.id, workspace.id);
      expect(changed.name, workspace.name);
      expect(changed.appServerAddress, workspace.appServerAddress);
      expect(changed.protectedFiles, workspace.protectedFiles);
    }
  });
}
