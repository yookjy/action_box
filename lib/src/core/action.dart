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

  String serializeParameter(TParam? param) {
    try {
      return json.encode(param);
    } catch (error) {
      throw Exception(
          'The "serializeParameters(TParam param)" method must be overridden.');
    }
  }

  String serializeResult(TResult result) {
    try {
      return json.encode(result);
    } catch (error) {
      throw Exception(
          'The "serializeResult(TResult result)" method must be overridden.');
    }
  }

  TResult deserializeResult(String source) {
    try {
      return json.decode(source);
    } catch (error) {
      throw Exception(
          'The "deserializeResult(String source)" method must be overridden.');
    }
  }

  @override
  FutureOr dispose() {
    _pipeline?.close();
  }
}
