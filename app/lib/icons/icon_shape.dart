sealed class IconShape {
  const IconShape();
}

final class IconPathShape extends IconShape {
  const IconPathShape(this.pathData);

  final String pathData;
}

final class IconCircleShape extends IconShape {
  const IconCircleShape({
    required this.centerHorizontal,
    required this.centerVertical,
    required this.radius,
  });

  final double centerHorizontal;
  final double centerVertical;
  final double radius;
}

final class IconRectangleShape extends IconShape {
  const IconRectangleShape({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.cornerRadius,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final double cornerRadius;
}
