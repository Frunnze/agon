import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/layout_density.dart';

typedef FontSizePair = ({double regular, double dense});

const List<FontSizePair> _fontSizePairsFromSmallest = <FontSizePair>[
  (regular: AppFontSizes.caption, dense: AppDenseFontSizes.caption),
  (regular: AppFontSizes.small, dense: AppDenseFontSizes.small),
  (regular: AppFontSizes.body, dense: AppDenseFontSizes.body),
  (regular: AppFontSizes.heading, dense: AppDenseFontSizes.heading),
  (regular: AppFontSizes.title, dense: AppDenseFontSizes.title),
  (regular: AppFontSizes.hero, dense: AppDenseFontSizes.hero),
];

double denseFontSizeFor(double regularFontSize) {
  if (regularFontSize < 0 || !regularFontSize.isFinite) {
    throw ArgumentError.value(
      regularFontSize,
      'regularFontSize',
      'must be finite and not negative',
    );
  }

  final FontSizePair smallestPair = _fontSizePairsFromSmallest.first;
  if (regularFontSize <= smallestPair.regular) {
    return _scaleLikePair(smallestPair, regularFontSize);
  }

  for (int index = 1; index < _fontSizePairsFromSmallest.length; index += 1) {
    final FontSizePair largerPair = _fontSizePairsFromSmallest[index];
    if (regularFontSize <= largerPair.regular) {
      final FontSizePair smallerPair = _fontSizePairsFromSmallest[index - 1];
      return _interpolateBetween(smallerPair, largerPair, regularFontSize);
    }
  }

  final FontSizePair largestPair = _fontSizePairsFromSmallest.last;
  return _scaleLikePair(largestPair, regularFontSize);
}

double fontSizeForDensity({
  required double regularFontSize,
  required LayoutDensity layoutDensity,
}) {
  if (layoutDensity.isTouch) {
    return regularFontSize;
  }
  return denseFontSizeFor(regularFontSize);
}

double _scaleLikePair(FontSizePair pair, double regularFontSize) {
  final double denseShare = pair.dense / pair.regular;
  return regularFontSize * denseShare;
}

double _interpolateBetween(
  FontSizePair smallerPair,
  FontSizePair largerPair,
  double regularFontSize,
) {
  final double regularSpan = largerPair.regular - smallerPair.regular;
  final double denseSpan = largerPair.dense - smallerPair.dense;
  final double shareOfSpan =
      (regularFontSize - smallerPair.regular) / regularSpan;
  return smallerPair.dense + shareOfSpan * denseSpan;
}
