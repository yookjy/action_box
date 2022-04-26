import 'dart:async';

import 'package:action_box/src/core/action_error.dart';
import 'package:action_box/src/core/channel.dart';
import 'package:action_box/src/core/transformed_result.dart';
import 'package:action_box/src/utils/disposable.dart';
import 'package:action_box/src/utils/tuple.dart';

abstract class Action<TParam, TResult> implements Disposable {
  final Channel general = Channel();

  StreamController<Tuple2<Channel, TResult>>? _pipeline;
  StreamController<Tuple2<Channel, TResult>> get pipeline =>
      _pipeline ??= createPipeline();
  StreamController<Tuple2<Channel, TResult>> createPipeline() =>
      StreamController.broadcast();

  FutureOr<Stream<TResult>> process(TParam param);

  TransformedResult<TResult>? transform(ActionError error) {
    return null;
  }

  @override
  FutureOr dispose() {
    _pipeline?.close();
  }
}
