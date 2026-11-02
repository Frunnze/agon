import 'dart:math';

const int propertyIterations = 200;
const int widgetPropertyIterations = 12;
const int _largestTextLength = 40;
const int _firstPrintableCodeUnit = 32;
const int _printableCodeUnitSpan = 95;
const int _unicodeSampleSpan = 0x2FFF;
const int _earliestYear = 2000;
const int _yearSpan = 60;
const int _monthsPerYear = 12;
const int _largestDayInEveryMonth = 28;
const int _secondsPerMinute = 60;

const List<String> _sampleWords = <String>[
  'release',
  'ship',
  'build',
  'docs',
  'ranker',
  'nightly',
  'Mac',
  '2.4',
  'café',
  '',
  '  ',
  '--',
  'Ünïcødé',
  'tests',
];

Random seededRandom(int seed) => Random(seed);

String randomText(Random random) {
  final int length = random.nextInt(_largestTextLength);
  final StringBuffer buffer = StringBuffer();

  for (int i = 0; i < length; i += 1) {
    final bool usesUnicode = random.nextInt(4) == 0;
    final int codeUnit = usesUnicode
        ? _firstPrintableCodeUnit + random.nextInt(_unicodeSampleSpan)
        : _firstPrintableCodeUnit + random.nextInt(_printableCodeUnitSpan);
    buffer.writeCharCode(codeUnit);
  }

  return buffer.toString();
}

String randomWordPhrase(Random random) {
  final int wordCount = random.nextInt(5);
  final List<String> words = <String>[];

  for (int i = 0; i < wordCount; i += 1) {
    words.add(_sampleWords[random.nextInt(_sampleWords.length)]);
  }

  return words.join(' ');
}

DateTime randomUtcMoment(Random random) {
  return DateTime.utc(
    _earliestYear + random.nextInt(_yearSpan),
    1 + random.nextInt(_monthsPerYear),
    1 + random.nextInt(_largestDayInEveryMonth),
    random.nextInt(Duration.hoursPerDay),
    random.nextInt(Duration.minutesPerHour),
    random.nextInt(_secondsPerMinute),
  );
}

DateTime randomLocalMoment(Random random) {
  final DateTime utcMoment = randomUtcMoment(random);

  return DateTime(
    utcMoment.year,
    utcMoment.month,
    utcMoment.day,
    utcMoment.hour,
    utcMoment.minute,
    utcMoment.second,
  );
}

T pickOne<T>(Random random, List<T> choices) {
  return choices[random.nextInt(choices.length)];
}

double randomWidth(
  Random random, {
  required double least,
  required double most,
}) {
  return least + random.nextDouble() * (most - least);
}
