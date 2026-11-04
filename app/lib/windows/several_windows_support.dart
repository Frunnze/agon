import 'package:flutter/foundation.dart';

bool supportsSeveralWindows(TargetPlatform platform) {
  return platform == TargetPlatform.macOS;
}
