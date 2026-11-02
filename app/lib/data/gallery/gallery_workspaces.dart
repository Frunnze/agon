import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

const String _appServerAddress =
    'peer://4f7a2c19e8b3d6a05c1f9e27b4d8a3c6f0e5b9d2a7c4e1f8b3d6a09c5e2f7b14';
const Duration _appServerRetryInterval = Duration(seconds: 10);

const List<Workspace> galleryWorkspaces = <Workspace>[
  Workspace(
    id: GalleryWorkspaceIds.acme,
    name: 'acme',
    appServerAddress: _appServerAddress,
  ),
  Workspace(
    id: GalleryWorkspaceIds.personal,
    name: 'personal',
    appServerAddress: _appServerAddress,
  ),
];

final AppServerStatus galleryAppServerStatus = AppServerStatus(
  address: _appServerAddress,
  state: AppServerState.online,
  lastConnectedAt: galleryNow,
  retryInterval: _appServerRetryInterval,
);

final AppServerGroup galleryAppServerGroup = AppServerGroup(
  members: const <AppServerMember>[
    AppServerMember(
      deviceId: GalleryDeviceIds.mainMac,
      standing: ServerStanding.active,
    ),
    AppServerMember(
      deviceId: GalleryDeviceIds.oldMacbook,
      standing: ServerStanding.backup,
    ),
  ],
  thisDeviceStanding: ThisDeviceStanding.none,
  canKeepBackup: true,
);

Repository _buildGitHubRepository(String path, AgentAccess agentAccess) {
  return Repository(
    address: 'github.com/$path',
    defaultBranch: 'main',
    agentAccess: agentAccess,
  );
}

final List<Project> galleryProjects = List<Project>.unmodifiable(<Project>[
  Project(
    id: GalleryProjectIds.acmeApp,
    workspaceId: GalleryWorkspaceIds.acme,
    name: 'acme-app',
    repositories: <Repository>[
      _buildGitHubRepository('acme/app', AgentAccess.pushAfterApproval),
      _buildGitHubRepository('acme/api', AgentAccess.readOnly),
    ],
  ),
  Project(
    id: GalleryProjectIds.mlRanker,
    workspaceId: GalleryWorkspaceIds.acme,
    name: 'ml-ranker',
    repositories: <Repository>[
      _buildGitHubRepository('acme/ranker', AgentAccess.readOnly),
    ],
  ),
  Project(
    id: GalleryProjectIds.docs,
    workspaceId: GalleryWorkspaceIds.acme,
    name: 'docs',
    repositories: <Repository>[
      _buildGitHubRepository('acme/docs', AgentAccess.pushAfterApproval),
    ],
  ),
  Project(
    id: GalleryProjectIds.blog,
    workspaceId: GalleryWorkspaceIds.personal,
    name: 'blog',
    repositories: <Repository>[
      _buildGitHubRepository('air/blog', AgentAccess.pushAfterApproval),
    ],
  ),
]);
