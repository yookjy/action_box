import 'package:action_box/src/core/channel.dart';

class ActionError {
  final Object innerError;
  final Channel channel;
  bool handled = false;
  String? tag;
  ActionError(this.innerError, this.channel);
}
