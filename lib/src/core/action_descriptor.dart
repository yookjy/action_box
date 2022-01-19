import 'dart:async';

import 'package:action_box/src/cache/cache_provider.dart';
import 'package:action_box/src/cache/cache_strategy.dart';
import 'package:action_box/src/core/action.dart';
import 'package:action_box/src/core/action_error.dart';
import 'package:action_box/src/core/channel.dart';
import 'package:action_box/src/utils/cloneable.dart';
import 'package:action_box/src/utils/disposable.dart';
import 'package:action_box/src/utils/tuple.dart';

class ActionDescriptor<TAction extends Action<TParam, TResult>, TParam, TResult>
    implements Disposable {
  final TAction Function() _factory;
  late final TAction _action = _factory();

  String? alias;

  ActionDescriptor(this._factory);

  @override
  FutureOr dispose() {
    _action.dispose();
  }

  ActionExecutor<TParam, TResult, TAction> call(EventSink errorSink,
          Duration defaultTimeout, CacheProvider cacheProvider) =>
      _ActionExecutor(this, errorSink, defaultTimeout, cacheProvider);
}

abstract class ActionExecutor<TParam, TResult,
    TAction extends Action<TParam, TResult>> {
  final ActionDescriptor<TAction, TParam, TResult> _descriptor;
  final EventSink _universalStreamSink;
  final Duration _timeout;
  final CacheProvider _cacheProvider;
  ActionExecutor(this._descriptor, this._universalStreamSink, this._timeout,
      this._cacheProvider);

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
      Channel Function(TAction)? channel});

  void drain(
      {TParam? param,
      Function? begin,
      Function(bool)? end,
      Channel Function(TAction)? channel,
      List<EventSink> Function(EventSink universal, EventSink pipeline)?
          errorSinks,
      Duration? timeout});

  void go(
      {TParam? param,
      Function? begin,
      Function(bool)? end,
      Channel Function(TAction)? channel,
      CacheStrategy? cacheStrategy,
      List<EventSink> Function(EventSink universal, EventSink pipeline)?
          errorSinks,
      Duration? timeout});

  Stream<TResult?> map({Channel Function(TAction)? channel});
}

class _ActionExecutor<TParam, TResult, TAction extends Action<TParam, TResult>>
    extends ActionExecutor<TParam, TResult, TAction> {
  _ActionExecutor(
      ActionDescriptor<TAction, TParam, TResult> descriptor,
      EventSink universalStreamSink,
      Duration timeout,
      CacheProvider cacheProvider)
      : super(descriptor, universalStreamSink, timeout, cacheProvider);

  TAction get _action => _descriptor._action;
  StreamController<Tuple2<Channel, TResult?>> get _pipeline => _action.pipeline;

  @override
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

  @override
  void drain(
          {TParam? param,
          Function? begin,
          Function(bool)? end,
          Channel Function(TAction)? channel,
          List<EventSink> Function(EventSink universal, EventSink pipeline)?
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

  @override
  void go(
          {TParam? param,
          Function? begin,
          Function(bool)? end,
          Channel Function(TAction)? channel,
          CacheStrategy? cacheStrategy,
          List<EventSink> Function(EventSink universal, EventSink pipeline)?
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

  @override
  Stream<TResult?> map({Channel Function(TAction)? channel}) {
    final channels = _getChannel(channel).ids.toSet();
    // Map the selected channel and pipeline of actions.
    bool validateChannels(Channel ch) =>
        ch.ids.toSet().intersection(channels).isNotEmpty;

    final source = _pipeline.stream
        .where((x) => validateChannels(x.item1))
        .handleError((e) {
      //If the channel does not match, it is ignored.
    }, test: (e) {
      if (e is ActionError && validateChannels(e.channel)) {
        return false;
      }
      return true;
    }).map<TResult?>((x) => x.item2);
    return source.map((x) => x is Cloneable ? x.clone() : x);
  }

  void _dispatch(
      {TParam? param,
      Stream<TResult>? result,
      Function? begin,
      Function(bool)? end,
      Channel Function(TAction)? channel,
      CacheStrategy? cacheStrategy,
      List<EventSink> Function(EventSink universal, EventSink pipeline)?
          errorSinks,
      Duration? timeout,
      bool subscribable = true}) async {
    var done = false;
    var errorStreamSinks = errorSinks?.call(_universalStreamSink, _pipeline) ??
        (subscribable ? [_pipeline] : [_universalStreamSink]);
    final channel$ = _getChannel(channel);

    void _addError(Object error, [StackTrace? stackTrace]) {
      errorStreamSinks
          .where((sink) => subscribable || (sink != _pipeline))
          .forEach((sink) {
        sink.addError(ActionError(error, channel$), stackTrace);
      });
    }

    try {
      begin?.call();

      // validate mandatory parameter
      if (result == null && !(null is TParam) && param == null) {
        throw ArgumentError.notNull('action parameter');
      }

      if (_descriptor.alias?.isEmpty ?? true) {
        throw Exception('An alias must be set.');
      }

      StreamSubscription? temporalSubscription;
      // Emit the executed result of the action to the selected channel.
      temporalSubscription = (result ??
              await _cacheProvider.readCache(
                  _descriptor.alias!, _action.process, cacheStrategy, param))
          .timeout(timeout ?? _timeout)
          .transform<Tuple2<Channel, TResult?>>(
              StreamTransformer.fromHandlers(handleData: (data, sink) {
            sink.add(Tuple2(channel$, data));
            _cacheProvider.writeCache(
                _descriptor.alias!, cacheStrategy, data, param);
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
        _addError(error, stackTrace);
      }, onDone: () {
        end?.call(done);
        temporalSubscription?.cancel();
      });
    } catch (error, stackTrace) {
      _addError(error, stackTrace);
      end?.call(done);
    }
  }

  /// If no channel is specified, the default channel is selected.
  Channel _getChannel([Channel Function(TAction)? channel]) =>
      channel?.call(_action) ?? _action.defaultChannel;
}
