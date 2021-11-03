import 'dart:async';

import 'package:action_box/action_box.dart';
import 'package:action_box/src/actions/action.dart';
import 'package:action_box/src/actions/transformed_result.dart';
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

  Tuple2<ActionDescriptor<TAction, TParam, TResult>, StreamController?> call(
          StreamController? sink) =>
      Tuple2(this, sink);
}

extension ActionDescriptorExtension<TAction extends Action<TParam, TResult>,
        TParam, TResult>
    on Tuple2<ActionDescriptor<TAction, TParam, TResult>, StreamController?> {
  void go(
      {TParam? param,
      Function? begin,
      Function? end,
      Channel Function(TAction)? channel,
      StreamController? errorSink,
      Duration timeout = const Duration(seconds: 10),
      bool subscribeable = true}) async {
    var errorStreamSink = errorSink ?? value2;
    try {
      begin?.call();

      final actionStream = (await value1._action.process(param))
          .timeout(timeout)
          .transform<TResult>(StreamTransformer.fromHandlers(
              handleError: (error, stackTrace, sink) {
        TransformedResult transformedResult = value1._action.transform(error);
        if (transformedResult.isTransformed) {
          sink.add(transformedResult.result);
          return;
        }
        errorStreamSink?.add(error);
        //_errorStreamController?.add(error);
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
        final channel$ =
            channel?.call(value1._action) ?? value1._action.defaultChannel;

        // 채널 추가
        final ob = actionStream.transform<Tuple2<Channel, TResult?>>(
            StreamTransformer.fromHandlers(handleData: (x, sink) {
          sink.add(Tuple2(channel$, x));
        }));

        // 채널에 해당하는 액션에 데이터 배출
        temporalSubscription = ob.listen((result) {
          value1._action.pipeline.add(result);
          temporalSubscription?.cancel();
          end?.call();
        });
      }
    } catch (error) {
      errorStreamSink?.add(error);
      //      _errorStreamController?.add(error);
      end?.call();
    }
  }

  Stream<TResult?> map({Channel Function(TAction)? channel}) {
    // 별도의 채널을 요청하지 않았으면 기본채널 선택
    final channels =
        (channel?.call(value1._action) ?? value1._action.defaultChannel)
            .ids
            .toSet();
    // 액션에 해당하는 소스 선택
    final source = value1._action.pipeline.stream
        .where((x) => x.value1.ids.toSet().intersection(channels).isNotEmpty)
        .map<TResult?>((x) => x.value2);
    return source.map((x) => x is Cloneable ? x.clone() : x);
  }
}
