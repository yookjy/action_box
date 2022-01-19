import 'package:action_box/src/core/channel.dart';

class ActionError {
  Object innerError;
  Channel channel;
  ActionError(this.innerError, this.channel);
}
