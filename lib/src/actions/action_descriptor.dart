import 'dart:async';

import 'package:action_box/action_box.dart';
import 'package:action_box/src/actions/action.dart';
import 'package:action_box/src/channels/channel.dart';
import 'package:action_box/src/utils/cloneable.dart';
import 'package:action_box/src/utils/tuple.dart';

int seconds = 4;

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
          StreamController? errorSink, Duration defaultTimeout) =>
      ActionExecutor(this, errorSink, defaultTimeout);
}

class ActionExecutor<TParam, TResult, TAction extends Action<TParam, TResult>> {
  final ActionDescriptor<TAction, TParam, TResult> _descriptor;
  final StreamController? _errorSink;
  final Duration _timeout;
  ActionExecutor(this._descriptor, this._errorSink, this._timeout);

  void go(
      {TParam? param,
      Function? begin,
      Function? end,
      Channel Function(TAction)? channel,
      StreamController? errorSink,
      Duration? timeout,
      bool subscribeable = true}) async {
    var errorStreamSink = errorSink ?? _errorSink;
    try {
      begin?.call();

      final isNullableParameter = null is TParam;
      if (!isNullableParameter && param == null) {
        throw ArgumentError.notNull('action parameter');
      }

      final actionStream = (await _descriptor._action.process(param))
          .timeout(timeout ?? _timeout)
          .transform<TResult?>(StreamTransformer.fromHandlers(
              handleError: (error, stackTrace, EventSink<TResult?> sink) {
        final transformedResult = _descriptor._action.transform(error);
        if (transformedResult.isTransformed) {
          sink.add(transformedResult.result);
          return;
        }
        errorStreamSink?.add(error);
        end?.call();
      }));

      StreamSubscription? temporalSubscription;
      if (!subscribeable) {
        //더미
        temporalSubscription = actionStream.listen((_) {
          temporalSubscription?.cancel();
          end?.call();
        });
      } else {
        // 별도의 채널을 요청하지 않았으면 기본채널 선택
        final channel$ = channel?.call(_descriptor._action) ??
            _descriptor._action.defaultChannel;

        // 채널 추가
        final ob = actionStream.transform<Tuple2<Channel, TResult?>>(
            StreamTransformer.fromHandlers(handleData: (x, sink) {
          sink.add(Tuple2(channel$, x));
        }));

        // 채널에 해당하는 액션에 데이터 배출
        temporalSubscription = ob.listen((result) {
          _descriptor._action.pipeline.add(result);
          temporalSubscription?.cancel();
          end?.call();
        });
      }
    } catch (error) {
      errorStreamSink?.add(error);
      end?.call();
    }
  }

  Stream<TResult?> map({Channel Function(TAction)? channel}) {
    // 별도의 채널을 요청하지 않았으면 기본채널 선택
    final channels = (channel?.call(_descriptor._action) ??
            _descriptor._action.defaultChannel)
        .ids
        .toSet();
    // 액션에 해당하는 소스 선택
    final source = _descriptor._action.pipeline.stream
        .where((x) => x.item1.ids.toSet().intersection(channels).isNotEmpty)
        .map<TResult?>((x) => x.item2);
    return source.map((x) => x is Cloneable ? x.clone() : x);
  }
}
