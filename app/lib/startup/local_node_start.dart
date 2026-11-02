import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'package:agent_orchestration/bridge/native/native_library_source.dart';
import 'package:agent_orchestration/bridge/native/native_node_transport.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/bridge/node/node_lifecycle.dart';
import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/startup/app_build_mode.dart';
import 'package:agent_orchestration/startup/identity_store_choice.dart';
import 'package:agent_orchestration/storage.dart';

const String _nodeDataFolderName = 'node';

Future<NodeCommandChannel> startLocalNode() async {
  final NodeTransport transport = NativeNodeTransport(
    source: chooseBundledLibrarySource(Platform.operatingSystem),
  );
  final Directory supportFolder = await getApplicationSupportDirectory();
  final IdentityStoreSettings identityStore = await chooseIdentityStore(
    operatingSystem: Platform.operatingSystem,
    buildMode: readAppBuildMode(),
    secrets: const SecureSecretStore(storage: FlutterSecureStorage()),
    random: Random.secure(),
  );
  final NodeStartConfiguration configuration = NodeStartConfiguration(
    dataDirectory:
        '${supportFolder.path}${Platform.pathSeparator}$_nodeDataFolderName',
    identityStore: identityStore,
    runner: const DetectedRunnerSettings(),
    peerRelay: PeerRelayChoice.defaultRelay,
  );

  try {
    await startNode(transport: transport, configuration: configuration);
  } on NodeCommandFailure catch (failure, stackTrace) {
    Error.throwWithStackTrace(translateNodeFailure(failure), stackTrace);
  }
  return NodeCommandChannel(transport: transport);
}
