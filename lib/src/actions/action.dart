
import 'package:action_box/src/actions/transformed_result.dart';
import 'package:action_box/src/channels/channel.dart';

abstract class Action<TParam, TResult> {

  TransformedResult<TResult?> transform(Object error) {
    return TransformedResult(false, null);
  }

  Stream<TResult?> process([TParam? param]);

  final Channel _channel = Channel();
  Channel get defaultChannel => _channel;
}