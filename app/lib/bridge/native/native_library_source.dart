const String androidSystemName = 'android';
const String linuxSystemName = 'linux';
const String windowsSystemName = 'windows';
const String macSystemName = 'macos';
const String iosSystemName = 'ios';

const String sharedObjectFileName = 'liborchestration_ffi.so';
const String windowsLibraryFileName = 'orchestration_ffi.dll';
const String macBundledLibraryPath =
    '@executable_path/../Frameworks/liborchestration_ffi.dylib';

sealed class NativeLibrarySource {
  const NativeLibrarySource();
}

final class LinkedIntoProcess extends NativeLibrarySource {
  const LinkedIntoProcess();
}

final class LibraryFile extends NativeLibrarySource {
  const LibraryFile({required this.path});

  final String path;
}

final class LinkedIntoProcessOrLibraryFile extends NativeLibrarySource {
  const LinkedIntoProcessOrLibraryFile({required this.path});

  final String path;
}

NativeLibrarySource chooseBundledLibrarySource(String operatingSystem) {
  return switch (operatingSystem) {
    androidSystemName ||
    linuxSystemName => const LibraryFile(path: sharedObjectFileName),
    windowsSystemName => const LibraryFile(path: windowsLibraryFileName),
    iosSystemName => const LinkedIntoProcess(),
    macSystemName => const LinkedIntoProcessOrLibraryFile(
      path: macBundledLibraryPath,
    ),
    _ => throw UnsupportedError('no node library for $operatingSystem'),
  };
}
