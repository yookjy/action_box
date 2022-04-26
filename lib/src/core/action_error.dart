import 'package:action_box/src/core/channel.dart';

class ActionError {
  final Object innerError;
  final Channel channel;
  bool handled = false;
  String? tag;
  ActionError(this.innerError, this.channel);

  @override
  String toString() {
    var buffer = StringBuffer()
      ..write('innerError: ')
      ..writeln(innerError)
      ..write('channel: ')
      ..writeln(channel)
      ..write('handled: ')
      ..writeln(handled)
      ..write('tag: ')
      ..writeln(tag);
    return buffer.toString();
  }
}
