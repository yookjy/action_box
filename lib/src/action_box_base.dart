import 'dart:async';

import 'package:action_box/src/actions/action.dart';
import 'package:action_box/src/actions/action_descriptor.dart';
import 'package:action_box/src/actions/action_directory.dart';
import 'package:action_box/src/actions/transformed_result.dart';
import 'package:action_box/src/channels/channel.dart';
import 'package:action_box/src/utils/pair.dart';
import 'package:rxdart/rxdart.dart';

abstract class ActionBox<TActionDirectory extends ActionDirectory> {

  static ActionDirectory? _actionDirectory;
  static late final Subject<Object> _exceptionSubject = PublishSubject<Object>()
    ..bufferTime(Duration(milliseconds: 500))
        .where((x) => x.isNotEmpty)
        .flatMap((x) => (x as PublishSubject<Object>).distinct((pre, cur) => pre == cur))
        .listen(errorHandler?.call);

  static Subject<Object> get exceptionSubject => _exceptionSubject;
  static Function(Object)? errorHandler;
  static Function(Object)? logWriter;

  void dispose() {
    _exceptionSubject.close();
  }

  static TActionDirectory getActionDirectory<TActionDirectory extends ActionDirectory>() {
    return _actionDirectory as TActionDirectory;
  }

  static void setActionDirectory<TActionDirectory extends ActionDirectory>(TActionDirectory actionDirectory) {
    if (_actionDirectory != null) {
      _actionDirectory!.dispose();
    }
    _actionDirectory = actionDirectory;
  }

  void call<TParam, TResult, TAction extends Action<TParam, TResult>> ({
    required ActionDescriptor<TAction, TParam, TResult> Function(TActionDirectory set) actionChooser,
    TParam? parameter,
    Function? begin,
    Function? end,
    Channel Function(TAction)? channelChooser,
    Duration timeout = const Duration(seconds: 10),
    bool subscribeable = true
  }) => dispatch(
    actionChooser: actionChooser,
    parameter: parameter,
    begin: begin,
    end: end,
    channelChooser: channelChooser,
    timeout: timeout,
    subscribeable: subscribeable
  );

  void dispatch<TParam, TResult, TAction extends Action<TParam, TResult>> ({
    required ActionDescriptor<TAction, TParam, TResult> Function(TActionDirectory set) actionChooser,
    TParam? parameter,
    Function? begin,
    Function? end,
    Channel Function(TAction)? channelChooser,
    Duration timeout = const Duration(seconds: 10),
    bool subscribeable = true
  }) {

    begin?.call();

    try {

      final descriptor = actionChooser.call(getActionDirectory<TActionDirectory>());
      final action = descriptor.action;
      final actionStream = action
          .process(parameter)
          .timeout(timeout)
          .onErrorResume((error, stackTrace) {
        TransformedResult transformedResult = action.transform(error);
        if (transformedResult.isTransformed) {
          logWriter?.call('transform() 이 정의되어 에러를 무시하고 데이터로 변환하여 배출합니다.');
          return Stream<TResult>.value(transformedResult.result);
        }
        logWriter?.call(error);
        exceptionSubject.add(error);
        end?.call();
        return Stream<TResult>.empty();
      });

      StreamSubscription? temporalSubscription;
      if (!subscribeable) {
        //더미
        temporalSubscription = actionStream.listen((_) {
          temporalSubscription?.cancel();
          end?.call();
        });
      } else {
        // 별도의 채널을 요청하지 않았으면 기본채널 선택
        final channel = channelChooser?.call(action) ?? action.defaultChannel;

        // 채널 추가
        final ob = actionStream.flatMap<Pair<Channel, TResult?>>((x) =>
            Stream.value(Pair(channel, x)));

        // 채널에 해당하는 액션에 데이터 배출
        temporalSubscription = ob.listen((result) {
          descriptor.pipeline.add(result);
          temporalSubscription?.cancel();
          end?.call();
        });
      }
    } catch(error) {
      exceptionSubject.add(error);
      logWriter?.call(error);
      end?.call();
    }
  }

  StreamSubscription subscribe<TParam, TResult, TAction extends Action<TParam, TResult>> ({
    required ActionDescriptor<TAction, TParam, TResult> Function(TActionDirectory set) actionChooser,
    required Function(TResult) onNext,
    Channel Function(TAction)? channelChooser,
    Stream<TResult>? Function(Stream<TResult>)? streamHandler,
    TResult Function(TResult)? copyResult,
  }) {

    return toStream(
        actionChooser: actionChooser,
        channelChooser: channelChooser,
        streamHandler: streamHandler,
        copyResult: copyResult
    ).listen(onNext);
  }

  static Stream<TResult> toStream<TParam, TResult, TAction extends Action<TParam, TResult>, TActionDirectory extends ActionDirectory> ({
    required ActionDescriptor<TAction, TParam, TResult> Function(TActionDirectory set) actionChooser,
    Channel Function(TAction)? channelChooser,
    Stream<TResult>? Function(Stream<TResult>)? streamHandler,
    TResult Function(TResult)? copyResult,
  }) {
    final actionDirectory = getActionDirectory<TActionDirectory>();
    final descriptor = actionChooser.call(actionDirectory);
    final action = descriptor.action;
    // 별도의 채널을 요청하지 않았으면 기본채널 선택
    final channels = (channelChooser?.call(action) ?? action.defaultChannel).ids.toSet();
    // 액션에 해당하는 소스 선택
    final source = descriptor.pipeline
        .where((x) => x.key.ids.toSet().intersection(channels).isNotEmpty)
        .flatMap<TResult>((x) => x.value == null ?
    Stream.empty() : Stream.value(x.value!));

    final stream = streamHandler?.call(source) ?? source;
    return stream.map((x) {
      var value = x;
      //배출할 데이터 복사
      if (copyResult != null) {
        value = copyResult.call(value);
      }
      return value;
    });
  }
}
