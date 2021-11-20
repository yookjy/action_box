import 'dart:async';

import 'package:action_box/action_box.dart';
import 'package:action_box/src/actions/action.dart';
import 'package:action_box/src/channels/channel.dart';
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
          EventSink errorSink, Duration defaultTimeout) =>
      ActionExecutor(this, errorSink, defaultTimeout);
}

class ActionExecutor<TParam, TResult, TAction extends Action<TParam, TResult>> {
  final ActionDescriptor<TAction, TParam, TResult> _descriptor;
  final EventSink _errorSink;
  final Duration _timeout;
  ActionExecutor(this._descriptor, this._errorSink, this._timeout);

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

  void waste(
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
          List<EventSink> Function(EventSink global, EventSink pipeline)?
              errorSinks,
          Duration? timeout}) =>
      _dispatch(
          param: param,
          begin: begin,
          end: end,
          channel: channel,
          errorSinks: errorSinks,
          timeout: timeout);

  void _dispatch(
      {TParam? param,
      Stream<TResult>? result,
      Function? begin,
      Function(bool)? end,
      Channel Function(TAction)? channel,
      List<EventSink> Function(EventSink global, EventSink pipeline)?
          errorSinks,
      Duration? timeout,
      bool subscribable = true}) async {
    var done = false;
    var errorStreamSinks =
        errorSinks?.call(_errorSink, _descriptor._action.pipeline) ??
            (subscribable ? [_descriptor._action.pipeline] : [_errorSink]);

    try {
      begin?.call();

      // validate mandatory parameter
      if (result == null && !(null is TParam) && param == null) {
        throw ArgumentError.notNull('action parameter');
      }

      StreamSubscription? temporalSubscription;

      // If no channel is specified, the default channel is selected.
      final channel$ = channel?.call(_descriptor._action) ??
          _descriptor._action.defaultChannel;

      // Emit the executed result of the action to the selected channel.
      temporalSubscription =
          (result ?? (await _descriptor._action.process(param)))
              .timeout(timeout ?? _timeout)
              .transform<Tuple2<Channel, TResult?>>(
                  StreamTransformer.fromHandlers(handleData: (data, sink) {
                sink.add(Tuple2(channel$, data));
              }, handleError: (error, stackTrace, sink) {
                final transformedResult = _descriptor._action.transform(error);
                if (transformedResult != null) {
                  sink.add(Tuple2(channel$, transformedResult.result));
                  return;
                }
                sink.addError(error, stackTrace);
              }))
              .listen((result) {
        done = true;
        if (subscribable) {
          _descriptor._action.pipeline.add(result);
        } else {
          // ignore
        }
      }, onError: (error, stackTrace) {
        errorStreamSinks
            .where((sink) =>
                subscribable || (sink != _descriptor._action.pipeline))
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
          .where(
              (sink) => subscribable || (sink != _descriptor._action.pipeline))
          .forEach((sink) {
        _addError(sink, error);
      });
      end?.call(done);
    }
  }

  void _addError(EventSink eventSink, Object error) {
    if (eventSink == _descriptor._action.pipeline) {
      eventSink.addError(error);
    } else {
      eventSink.add(error);
    }
  }

  Stream<TResult?> map({Channel Function(TAction)? channel}) {
    // If no channel is specified, the default channel is selected.
    final channels = (channel?.call(_descriptor._action) ??
            _descriptor._action.defaultChannel)
        .ids
        .toSet();
    // Map the selected channel and pipeline of actions.
    final source = _descriptor._action.pipeline.stream
        .where((x) => x.item1.ids.toSet().intersection(channels).isNotEmpty)
        .map<TResult?>((x) => x.item2);
    return source.map((x) => x is Cloneable ? x.clone() : x);
  }
}
