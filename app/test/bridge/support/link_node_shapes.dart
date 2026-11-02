import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/live_run_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import 'node_shapes.dart';
import 'random_account_json.dart';
import 'random_file_json.dart';
import 'random_live_json.dart';

const List<NodeShape> linkNodeShapes = <NodeShape>[
  NodeShape('run_event_from_json', randomRunEventJson, RunEvent.fromJson),
  NodeShape('watch_view_from_json', randomWatchViewJson, WatchView.fromJson),
  NodeShape(
    'peer_address_from_json',
    randomPeerAddressJson,
    PeerAddress.fromJson,
  ),
  NodeShape(
    'peer_announcement_from_json',
    randomPeerAnnouncementJson,
    PeerAnnouncement.fromJson,
  ),
  NodeShape(
    'sandbox_settings_from_json',
    randomSandboxSettingsJson,
    SandboxSettings.fromJson,
  ),
  NodeShape(
    'runner_settings_from_json',
    randomRunnerSettingsJson,
    RunnerSettings.fromJson,
  ),
  NodeShape(
    'repository_branches_view_from_json',
    randomRepositoryBranchesJson,
    RepositoryBranchesView.fromJson,
  ),
  NodeShape(
    'repository_holder_from_json',
    randomRepositoryHolderJson,
    RepositoryHolder.fromJson,
  ),
  NodeShape(
    'repository_entry_from_json',
    randomRepositoryEntryJson,
    RepositoryEntry.fromJson,
  ),
  NodeShape(
    'repository_folder_view_from_json',
    randomRepositoryFolderJson,
    RepositoryFolderView.fromJson,
  ),
  NodeShape(
    'file_preview_from_json',
    randomFilePreviewJson,
    FilePreview.fromJson,
  ),
  NodeShape(
    'repository_file_view_from_json',
    randomRepositoryFileJson,
    RepositoryFileView.fromJson,
  ),
];
