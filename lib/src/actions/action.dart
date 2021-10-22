import 'package:action_box/src/actions/transformed_result.dart';
import 'package:action_box/src/channels/channel.dart';

abstract class Action<TParam, TResult> {
  final Channel defaultChannel = Channel();

  Stream<TResult?> process([TParam? param]);

  TransformedResult<TResult?> transform(Object error) {
    return TransformedResult(false, null);
  }
}
