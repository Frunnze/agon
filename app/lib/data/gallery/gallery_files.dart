import 'package:agent_orchestration/data/fakes/fake_file_repository.dart';
import 'package:agent_orchestration/data/gallery/gallery_file_texts.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';

const String galleryAppRepositoryAddress = 'github.com/acme/app';
const String galleryApiRepositoryAddress = 'github.com/acme/api';
const int _iconSide = 1024;
const int _splashWidth = 1242;
const int _splashHeight = 2688;
const int _holderAgeInDays = 3;

final Map<String, RepositoryFileSource> galleryFileSources =
    Map<String, RepositoryFileSource>.unmodifiable(
      <String, RepositoryFileSource>{
        galleryAppRepositoryAddress: FilesFromRunner(
          runnerId: GalleryDeviceIds.officeServer,
          runnerName: 'office-server',
          branches: const <String>['main', 'release'],
          taskBranches: const <String>[
            'task/fix-login-redirect-a41c',
            'task/ship-release-2-4-9e07',
            'task/ship-release-2-3-5c18',
            galleryKeptBranch,
          ],
        ),
        galleryApiRepositoryAddress: FilesWithoutRunner(
          holders: <RepositoryHolder>[
            RepositoryHolder(
              deviceId: GalleryDeviceIds.oldMacbook,
              name: 'old-macbook',
              lastSeen: galleryDaysAgo(_holderAgeInDays),
            ),
          ],
        ),
      },
    );

FakeRepositoryFile _appText(String path, int size, String text) {
  return FakeRepositoryFile(
    repositoryAddress: galleryAppRepositoryAddress,
    path: path,
    size: size,
    preview: TextFilePreview(text),
  );
}

FakeRepositoryFile _appFile(String path, int size, FilePreview preview) {
  return FakeRepositoryFile(
    repositoryAddress: galleryAppRepositoryAddress,
    path: path,
    size: size,
    preview: preview,
  );
}

final List<FakeRepositoryFile> galleryRepositoryFiles =
    List<FakeRepositoryFile>.unmodifiable(<FakeRepositoryFile>[
      _appText('.github/workflows/release.yml', 486, galleryWorkflowText),
      _appText('android/build.gradle', 1310, galleryGradleText),
      _appFile(
        'assets/fonts/Inter.ttf',
        310412,
        const UnavailableFilePreview(PreviewUnavailableReason.binary),
      ),
      _appFile(
        'assets/icon.png',
        88064,
        ImageFilePreview(
          width: _iconSide,
          height: _iconSide,
          bytes: galleryIconBytes,
        ),
      ),
      _appFile(
        'assets/onboarding.mp4',
        25794970,
        const UnavailableFilePreview(PreviewUnavailableReason.tooLarge),
      ),
      _appFile(
        'assets/splash.png',
        421888,
        ImageFilePreview(
          width: _splashWidth,
          height: _splashHeight,
          bytes: galleryIconBytes,
        ),
      ),
      _appText('ios/Podfile', 702, galleryPodText),
      _appText('src/auth/login.ts', 2150, galleryLoginText),
      _appText('src/auth/redirect.ts', 940, galleryRedirectText),
      _appText('src/auth/session.ts', 3891, gallerySessionText),
      _appText('src/components/Button.tsx', 1720, galleryButtonText),
      _appText('src/screens/Home.tsx', 2468, galleryHomeText),
      _appText('src/App.tsx', 1229, galleryAppText),
      _appText('src/index.ts', 214, galleryIndexText),
      _appText('.gitignore', 312, galleryIgnoreText),
      _appText('package.json', 1946, galleryPackageText),
      _appText('README.md', 3277, galleryReadmeText),
      _appText('tsconfig.json', 618, galleryTypeScriptSettingsText),
    ]);
