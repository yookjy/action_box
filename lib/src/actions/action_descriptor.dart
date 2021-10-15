import 'dart:async';

import 'package:action_box/src/actions/action.dart';
import 'package:action_box/src/channels/channel.dart';
import 'package:action_box/src/utils/pair.dart';
import 'package:rxdart/rxdart.dart';

class ActionDescriptor<TAction extends Action<TParam, TResult>, TParam, TResult> {
  final TAction Function() factory;
  late final TAction _action = factory();
  TAction get action => _action;

  late final Subject<Pair<Channel, TResult?>> pipeline
    = PublishSubject<Pair<Channel, TResult?>>();

  ActionDescriptor(this.factory);

  FutureOr dispose() {
    return pipeline.close();
  }
}