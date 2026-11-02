abstract final class AppSpacing {
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 24;
  static const double space6 = 32;
  static const double space7 = 48;
  static const double space8 = 64;
}

abstract final class AppRadii {
  static const double control = 6;
  static const double panel = 10;
  static const double pill = 999;
}

abstract final class AppBorders {
  static const double thin = 1;
  static const double selected = 2;
  static const double route = 3;
}

abstract final class AppSizes {
  static const double icon = 20;
  static const double iconSmall = 16;
  static const double iconStroke = 1.75;
  static const double iconViewBox = 24;
  static const double controlHeight = 44;
  static const double controlHeightCompact = 40;
  static const double measure = 608;
  static const double railWidth = 208;
  static const double railWidthLarge = 240;
  static const double dialogMaximumWidth = 512;
  static const double dialogMaximumHeightShare = 0.92;
  static const double chatContextWidth = 320;
  static const double logMaximumHeight = 384;
  static const double listEndColumnMinimumWidth = 128;
  static const double listActionColumnMinimumWidth = 96;
  static const double tagInputFieldMinimumWidth = 128;
  static const double factColumnMinimumWidth = 128;
}

abstract final class AppDurations {
  static const Duration micro = Duration(milliseconds: 100);
  static const Duration enter = Duration(milliseconds: 320);
  static const Duration spin = Duration(seconds: 1);
  static const Duration cursorBlink = Duration(milliseconds: 1200);
}
