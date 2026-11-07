import 'dart:math';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/random_moments.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import 'support/domain_model_properties.dart';

const int _largestRetryMilliseconds = 3600000;

ModelFieldValues _randomWorkspaceFields(Random random) {
  return <Object?>[
    randomWorkspaceId(random),
    randomHostileText(random),
    randomHostileText(random),
    randomHostileTexts(random),
    pickOne(random, ApprovalPolicy.values),
  ];
}

Workspace _buildWorkspace(ModelFieldValues fieldValues) {
  return Workspace(
    id: fieldValues[0]! as WorkspaceId,
    name: fieldValues[1]! as String,
    appServerAddress: fieldValues[2]! as String,
    protectedFiles: fieldValues[3]! as List<String>,
    approvalPolicy: fieldValues[4]! as ApprovalPolicy,
  );
}

ModelFieldValues _readWorkspaceFieldsBesidesPolicy(Workspace workspace) {
  return <Object?>[
    workspace.id,
    workspace.name,
    workspace.appServerAddress,
    workspace.protectedFiles,
  ];
}

ModelFieldValues _readWorkspaceFields(Workspace workspace) {
  return <Object?>[
    ..._readWorkspaceFieldsBesidesPolicy(workspace),
    workspace.approvalPolicy,
  ];
}

Workspace _randomWorkspace(Random random) {
  return _buildWorkspace(_randomWorkspaceFields(random));
}

Workspace _buildWorkspaceWithProtectedFiles(
  Random random,
  List<String> protectedFiles,
) {
  return Workspace(
    id: randomWorkspaceId(random),
    name: randomHostileText(random),
    appServerAddress: randomHostileText(random),
    protectedFiles: protectedFiles,
    approvalPolicy: pickOne(random, ApprovalPolicy.values),
  );
}

List<String> _readProtectedFiles(Workspace workspace) {
  return workspace.protectedFiles;
}

void main() {
  testModelConstructorProperties(
    const ModelConstructor<Workspace>(
      testNamePrefix: 'test_workspace_constructor_property',
      seed: 704201,
      randomFieldValues: _randomWorkspaceFields,
      construct: _buildWorkspace,
      readFieldValues: _readWorkspaceFields,
    ),
  );

  testListCopyProperties(
    const ListCopy<Workspace, String>(
      testNamePrefix: 'test_workspace_constructor_property_protected_files',
      seed: 704211,
      buildElement: randomHostileText,
      construct: _buildWorkspaceWithProtectedFiles,
      readList: _readProtectedFiles,
    ),
  );

  testModelCopyProperties(
    ModelCopy<Workspace, ApprovalPolicy>(
      testNamePrefix: 'test_workspace_with_approval_policy_property',
      seed: 704221,
      randomModel: _randomWorkspace,
      randomChange: (Random random) => pickOne(random, ApprovalPolicy.values),
      applyChange: (Workspace workspace, ApprovalPolicy policy) =>
          workspace.withApprovalPolicy(policy),
      readChangedField: (Workspace workspace) => workspace.approvalPolicy,
      readOtherFields: _readWorkspaceFieldsBesidesPolicy,
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<AppServerStatus>(
      testNamePrefix: 'test_app_server_status_constructor_property',
      seed: 704231,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileText(random),
        pickOne(random, AppServerState.values),
        randomPreciseMoment(random),
        Duration(milliseconds: random.nextInt(_largestRetryMilliseconds)),
      ],
      construct: (ModelFieldValues fieldValues) => AppServerStatus(
        address: fieldValues[0]! as String,
        state: fieldValues[1]! as AppServerState,
        lastConnectedAt: fieldValues[2]! as DateTime,
        retryInterval: fieldValues[3]! as Duration,
      ),
      readFieldValues: (AppServerStatus status) => <Object?>[
        status.address,
        status.state,
        status.lastConnectedAt,
        status.retryInterval,
      ],
    ),
  );
}
