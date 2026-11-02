const int _bytesPerUnit = 1024;
const int _decimalPlaces = 1;
const int _tenths = 10;
const double _wholeKilobytesFrom = 10;
const String _byteUnit = 'B';
const String _kilobyteUnit = 'KB';
const List<String> _largeUnits = <String>['MB', 'GB'];

String describeFileSize(int bytes) {
  if (bytes < _bytesPerUnit) {
    return '$bytes $_byteUnit';
  }

  final double kilobytes = bytes / _bytesPerUnit;
  if (kilobytes < _bytesPerUnit) {
    return '${_describeKilobytes(kilobytes)} $_kilobyteUnit';
  }

  double value = kilobytes / _bytesPerUnit;
  int unitIndex = 0;
  while (value >= _bytesPerUnit && unitIndex < _largeUnits.length - 1) {
    value = value / _bytesPerUnit;
    unitIndex += 1;
  }
  final String shownValue = value.toStringAsFixed(_decimalPlaces);

  return '$shownValue ${_largeUnits[unitIndex]}';
}

String _describeKilobytes(double kilobytes) {
  final double roundedToTenths = (kilobytes * _tenths).round() / _tenths;
  if (roundedToTenths < _wholeKilobytesFrom) {
    return roundedToTenths.toStringAsFixed(_decimalPlaces);
  }
  return kilobytes.round().toString();
}
