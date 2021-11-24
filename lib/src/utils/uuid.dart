import 'dart:math';

class UUID {
  static String nil = '00000000-0000-0000-0000-000000000000';

  static String v4() {
    var random = Random();
    var buffer = StringBuffer();

    int _rand(Random random) => random.nextInt(16);
    String _getRandomHex(Random random) => _rand(random).toRadixString(16);

    void _fill(Random random, StringBuffer buffer, int length) {
      for (var i = 0; i < length; i++) {
        buffer.write(_getRandomHex(random));
      }
    }

    _fill(random, buffer, 8);
    buffer.write('-');
    _fill(random, buffer, 4);
    buffer.write('-');
    buffer.write('4'); // bits 12-15 of the time_hi_and_version field to 0010
    _fill(random, buffer, 3);
    buffer.write('-');
    buffer.write(((_rand(random) & 0x3) | 0x8)
        .toRadixString(16)); // bits 6-7 of the clock_seq_hi_and_reserved to 01
    _fill(random, buffer, 3);
    buffer.write('-');
    _fill(random, buffer, 12);

    return buffer.toString();
  }
}
