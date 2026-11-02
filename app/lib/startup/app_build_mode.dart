import 'package:flutter/foundation.dart';

enum AppBuildMode { debug, release }

AppBuildMode readAppBuildMode() {
  if (kDebugMode) {
    return AppBuildMode.debug;
  }
  return AppBuildMode.release;
}
