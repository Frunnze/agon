import 'package:agent_orchestration/icons/icon_shape.dart';

enum AppIconKind {
  tasks(<IconShape>[
    IconRectangleShape(
      left: 4,
      top: 4,
      width: 16,
      height: 16,
      cornerRadius: 3,
    ),
    IconPathShape('m8.5 12 2.5 2.5 4.5-5'),
  ]),
  approval(<IconShape>[
    IconPathShape('M12 3 5 6v5.5c0 4.2 2.9 7.9 7 9.5 4.1-1.6 7-5.3 7-9.5V6z'),
    IconPathShape('m9 12 2.2 2.2L15.5 10'),
  ]),
  jobs(<IconShape>[
    IconPathShape('m17 3 3 3-3 3'),
    IconPathShape('M4 12v-2a4 4 0 0 1 4-4h12'),
    IconPathShape('m7 21-3-3 3-3'),
    IconPathShape('M20 12v2a4 4 0 0 1-4 4H4'),
  ]),
  skills(<IconShape>[
    IconPathShape('M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3z'),
    IconPathShape('M5 17a3 3 0 0 1 3-3h11'),
  ]),
  rules(<IconShape>[
    IconPathShape('M6 3h9l3 3v15H6z'),
    IconPathShape('M9 10h6M9 14h6M9 18h4'),
  ]),
  more(<IconShape>[
    IconCircleShape(centerHorizontal: 5, centerVertical: 12, radius: 1.5),
    IconCircleShape(centerHorizontal: 12, centerVertical: 12, radius: 1.5),
    IconCircleShape(centerHorizontal: 19, centerVertical: 12, radius: 1.5),
  ]),
  workflow(<IconShape>[
    IconCircleShape(centerHorizontal: 6, centerVertical: 6, radius: 2.5),
    IconCircleShape(centerHorizontal: 6, centerVertical: 18, radius: 2.5),
    IconCircleShape(centerHorizontal: 18, centerVertical: 12, radius: 2.5),
    IconPathShape('M8.5 6.8 15.6 11M8.5 17.2l7.1-4.2'),
  ]),
  settings(<IconShape>[
    IconPathShape('M4 7h10M18 7h2M4 17h4M12 17h8'),
    IconCircleShape(centerHorizontal: 16, centerVertical: 7, radius: 2),
    IconCircleShape(centerHorizontal: 10, centerVertical: 17, radius: 2),
  ]),
  key(<IconShape>[
    IconCircleShape(centerHorizontal: 8, centerVertical: 15, radius: 4),
    IconPathShape('m10.8 12.2 8.2-8.2M15.5 7.5l2.5 2.5M13.5 9.5l2 2'),
  ]),
  chevronLeft(<IconShape>[IconPathShape('m15 5-7 7 7 7')]),
  chevronDown(<IconShape>[IconPathShape('m5 9 7 7 7-7')]),
  project(<IconShape>[
    IconPathShape(
      'M3 7a2 2 0 0 1 2-2h4l2 2h8'
      'a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5',
    ),
    IconPathShape('M5 19a2 2 0 0 1-2-2V7'),
  ]),
  chevronRight(<IconShape>[IconPathShape('m9 5 7 7-7 7')]),
  play(<IconShape>[IconPathShape('M8 5.5v13l10.5-6.5z')]),
  draft(<IconShape>[
    IconPathShape('m4 20 10-10'),
    IconPathShape('M15 3v3M19.5 4.5 17.5 6.5M21 9h-3M12.5 7.5l4 4'),
  ]),
  close(<IconShape>[IconPathShape('M7 7l10 10M17 7 7 17')]),
  plus(<IconShape>[IconPathShape('M12 5v14M5 12h14')]),
  chat(<IconShape>[IconPathShape('M4 5h16v11H10l-4 4v-4H4z')]),
  send(<IconShape>[IconPathShape('M12 19V5M6 11l6-6 6 6')]),
  spinner(<IconShape>[IconPathShape('M12 4a8 8 0 1 1-8 8')]),
  clock(<IconShape>[
    IconCircleShape(centerHorizontal: 12, centerVertical: 12, radius: 8),
    IconPathShape('M12 8v4l2.5 2'),
  ]),
  check(<IconShape>[IconPathShape('m5 12.5 4.5 4.5L19 7.5')]),
  alert(<IconShape>[
    IconPathShape('M12 4 3 19.5h18z'),
    IconPathShape('M12 10v4M12 16.8v.01'),
  ]),
  offline(<IconShape>[
    IconCircleShape(centerHorizontal: 12, centerVertical: 12, radius: 8),
    IconPathShape('m6.5 6.5 11 11'),
  ]),
  online(<IconShape>[
    IconCircleShape(centerHorizontal: 12, centerVertical: 12, radius: 8),
    IconCircleShape(centerHorizontal: 12, centerVertical: 12, radius: 3),
  ]),
  lock(<IconShape>[
    IconRectangleShape(
      left: 5,
      top: 11,
      width: 14,
      height: 9,
      cornerRadius: 2,
    ),
    IconPathShape('M8 11V8a4 4 0 0 1 8 0v3'),
  ]),
  person(<IconShape>[
    IconCircleShape(centerHorizontal: 12, centerVertical: 8, radius: 3.5),
    IconPathShape('M5 20a7 7 0 0 1 14 0'),
  ]),
  terminal(<IconShape>[IconPathShape('m5 7 5 5-5 5M12 17h7')]),
  edit(<IconShape>[
    IconPathShape('M4 20h4L19 9l-4-4L4 16z'),
    IconPathShape('m13.5 6.5 4 4'),
  ]),
  retry(<IconShape>[
    IconPathShape('M19.5 12a7.5 7.5 0 1 1-2.2-5.3'),
    IconPathShape('M19.5 4.5V9H15'),
  ]),
  newWindow(<IconShape>[
    IconPathShape('M10 5H6a2 2 0 0 0-2 2v11a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2v-4'),
    IconPathShape('M14 4h6v6M20 4l-8 8'),
  ]),
  pin(<IconShape>[IconPathShape('M9 4h6M10 4v6l-3 4h10l-3-4V4M12 14v6')]);

  const AppIconKind(this.shapes);

  final List<IconShape> shapes;
}
