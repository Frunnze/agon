import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

const Curve _riseCurve = Curves.easeOut;
const double _riseDistance = AppSpacing.space2;

final class RisingPage extends Page<Object?> {
  const RisingPage({required super.key, required this.child});

  final Widget child;

  @override
  Route<Object?> createRoute(BuildContext context) {
    return _RisingPageRoute(page: this);
  }
}

class _RisingPageRoute extends PageRoute<Object?> {
  _RisingPageRoute({required RisingPage page}) : super(settings: page);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => AppDurations.enter;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final RisingPage currentPage = settings as RisingPage;
    return currentPage.child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return ColoredBox(color: AppColors.paper, child: child);
    }

    final Animation<double> progress = CurvedAnimation(
      parent: animation,
      curve: _riseCurve,
    );
    return ColoredBox(
      color: AppColors.paper,
      child: FadeTransition(
        opacity: progress,
        child: _RisingContent(progress: progress, child: child),
      ),
    );
  }
}

class _RisingContent extends AnimatedWidget {
  const _RisingContent({
    required Animation<double> progress,
    required this.child,
  }) : super(listenable: progress);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Animation<double> progress = listenable as Animation<double>;
    final double remainingDistance = _riseDistance * (1 - progress.value);

    return Transform.translate(
      offset: Offset(0, remainingDistance),
      child: child,
    );
  }
}
