import 'dart:async';
import 'dart:convert';

import 'package:action_box/action_box.dart';
import 'package:action_box/src/core/channel.dart';
import 'package:action_box/src/core/transformed_result.dart';
import 'package:action_box/src/utils/tuple.dart';

abstract class Action<TParam, TResult> implements Disposable {
  final Channel defaultChannel = Channel();

  StreamController<Tuple2<Channel, TResult?>>? _pipeline;
  StreamController<Tuple2<Channel, TResult?>> get pipeline =>
      _pipeline ?? (_pipeline = createPipeline());
  StreamController<Tuple2<Channel, TResult?>> createPipeline() =>
      StreamController.broadcast();

  FutureOr<Stream<TResult>> process([TParam? param]);

  TransformedResult<TResult>? transform(Object error) {
    return null;
  }

  Object? Function(Object? key, Object? value)? get paramReviver => null;

  Object? Function(Object? object)? get paramToJson => null;

  Object? Function(Object? key, Object? value)? get resultReviver => null;

  Object? Function(Object? object)? get resultToJson => null;

  @override
  FutureOr dispose() {
    _pipeline?.close();
  }
}
