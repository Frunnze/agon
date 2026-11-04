import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/layout_size.dart';

EdgeInsets pagePaddingFor(LayoutSize layoutSize) {
  switch (layoutSize) {
    case LayoutSize.compact:
      return const EdgeInsets.all(AppSpacing.space4);
    case LayoutSize.medium:
      return const EdgeInsets.all(AppSpacing.space6);
    case LayoutSize.large:
      return const EdgeInsets.symmetric(
        horizontal: AppSpacing.space7,
        vertical: AppSpacing.space6,
      );
  }
}

const double pageGap = AppSpacing.space5;
