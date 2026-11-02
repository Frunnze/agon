import 'package:flutter/foundation.dart';

const String chooseFolderLabel = 'Choose folder…';

bool canChooseFolders(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.iOS:
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
      return false;
  }
}
