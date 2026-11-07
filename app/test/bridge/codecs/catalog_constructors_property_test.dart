import 'support/catalog_codec_rows.dart';
import 'support/codec_rows.dart';

const int _firstSeed = 9340000;

void main() {
  testConstructorRows(rows: catalogConstructorRows, firstSeed: _firstSeed);
}
