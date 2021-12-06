import 'dart:async';

import 'package:action_box/action_box.dart';
import 'package:action_box/src/cache/cache_provider.dart';
import 'package:action_box/src/cache/cache_storage.dart';
import 'package:action_box/src/cache/cache_strategy.dart';
import 'package:action_box/src/core/action.dart';
import 'package:action_box/src/core/channel.dart';
import 'package:action_box/src/utils/cloneable.dart';
import 'package:action_box/src/utils/tuple.dart';

class ActionDescriptor<TAction extends Action<TParam, TResult>, TParam, TResult>
    implements Disposable {
  final TAction Function() _factory;
  late final TAction _action = _factory();

  ActionDescriptor(this._factory);

  @override
  FutureOr dispose() {
    _action.dispose();
  }

  ActionExecutor<TParam, TResult, TAction> call(
          EventSink errorSink, Duration defaultTimeout, CacheProvider cacheProvider) =>
      ActionExecutor(this, errorSink, defaultTimeout, cacheProvider);
}

class ActionExecutor<TParam, TResult, TAction extends Action<TParam, TResult>> {
  final ActionDescriptor<TAction, TParam, TResult> _descriptor;
  final EventSink _globalErrorSink;
  final Duration _timeout;
  final CacheProvider _cacheProvider;
  ActionExecutor(this._descriptor, this._globalErrorSink, this._timeout, this._cacheProvider);

  TAction get _action => _descriptor._action;
  StreamController<Tuple2<Channel, TResult?>> get _pipeline => _action.pipeline;

  ActionExecutor<TParam, TResult, TAction> when(bool Function() test,
      Function(ActionExecutor<TParam, TResult, TAction>) executor) {
    if (test()) {
      executor.call(this);
    }
    return this;
  }

  void echo(
          {required TResult value,
          Function? begin,
          Function(bool)? end,
          Channel Function(TAction)? channel}) =>
      _dispatch(
          result: Stream.value(value),
          begin: begin,
          end: end,
          channel: channel);

  void drain(
          {TParam? param,
          Function? begin,
          Function(bool)? end,
          Channel Function(TAction)? channel,
          List<EventSink> Function(EventSink global, EventSink pipeline)?
              errorSinks,
          Duration? timeout}) =>
      _dispatch(
          param: param,
          begin: begin,
          end: end,
          channel: channel,
          errorSinks: errorSinks,
          timeout: timeout,
          subscribable: false);

  void go(
          {TParam? param,
          Function? begin,
          Function(bool)? end,
          Channel Function(TAction)? channel,
          CacheStrategy? cacheStrategy,
          List<EventSink> Function(EventSink global, EventSink pipeline)?
              errorSinks,
          Duration? timeout}) =>
      _dispatch(
          param: param,
          begin: begin,
          end: end,
          channel: channel,
          cacheStrategy: cacheStrategy,
          errorSinks: errorSinks,
          timeout: timeout);

  void _dispatch(
      {TParam? param,
      Stream<TResult>? result,
      Function? begin,
      Function(bool)? end,
      Channel Function(TAction)? channel,
      CacheStrategy? cacheStrategy,
      List<EventSink> Function(EventSink global, EventSink pipeline)?
          errorSinks,
      Duration? timeout,
      bool subscribable = true}) async {
    var done = false;
    var errorStreamSinks = errorSinks?.call(_globalErrorSink, _pipeline) ??
        (subscribable ? [_pipeline] : [_globalErrorSink]);

    try {
      begin?.call();

      // validate mandatory parameter
      if (result == null && !(null is TParam) && param == null) {
        throw ArgumentError.notNull('action parameter');
      }

      StreamSubscription? temporalSubscription;
      final channel$ = _getChannel(channel);

      // Emit the executed result of the action to the selected channel.
      temporalSubscription = (result ?? await _cacheProvider.readCacheIfAbsent(_action, cacheStrategy, param))
      // temporalSubscription = (result ?? await  _action.process(param))
          .timeout(timeout ?? _timeout)
          .transform<Tuple2<Channel, TResult?>>(
              StreamTransformer.fromHandlers(handleData: (data, sink) {
            sink.add(Tuple2(channel$, data));
            _cacheProvider.writeCache(_action, cacheStrategy, data, param);
          }, handleError: (error, stackTrace, sink) {
            final transformedResult = _action.transform(error);
            if (transformedResult != null) {
              sink.add(Tuple2(channel$, transformedResult.result));
              return;
            }
            sink.addError(error, stackTrace);
          }))
          .listen((result) {
        done = true;
        if (subscribable) {
          _pipeline.add(result);
        } else {
          // ignore
        }
      }, onError: (error, stackTrace) {
        errorStreamSinks
            .where((sink) => subscribable || (sink != _pipeline))
            .forEach((sink) {
          var err = stackTrace == null ? error : Tuple2(error, stackTrace);
          _addError(sink, err);
        });
      }, onDone: () async {
        end?.call(done);
        await temporalSubscription?.cancel();
      });
    } catch (error) {
      errorStreamSinks
          .where((sink) => subscribable || (sink != _pipeline))
          .forEach((sink) {
        _addError(sink, error);
      });
      end?.call(done);
    }
  }

  void _addError(EventSink eventSink, Object error) {
    if (eventSink == _pipeline) {
      eventSink.addError(error);
    } else {
      eventSink.add(error);
    }
  }

  /// If no channel is specified, the default channel is selected.
  Channel _getChannel([Channel Function(TAction)? channel]) =>
      channel?.call(_action) ?? _action.defaultChannel;

  Stream<TResult?> map({Channel Function(TAction)? channel}) {
    final channels = _getChannel(channel).ids.toSet();
    // Map the selected channel and pipeline of actions.
    final source = _pipeline.stream
        .where((x) => x.item1.ids.toSet().intersection(channels).isNotEmpty)
        .map<TResult?>((x) => x.item2);
    return source.map((x) => x is Cloneable ? x.clone() : x);
  }
}
