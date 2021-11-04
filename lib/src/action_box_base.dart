import 'dart:async';

import 'package:action_box/src/actions/action.dart';
import 'package:action_box/src/actions/action_descriptor.dart';
import 'package:action_box/src/actions/action_directory.dart';
import 'package:action_box/src/utils/tuple.dart';

abstract class ActionBoxBase<TActionDirectory extends ActionDirectory> {
  late final TActionDirectory _root = _rootFactory.call();
  late final TActionDirectory Function() _rootFactory;
  late final StreamController? _errorStreamController =
      _errorStreamFactory?.call();
  final StreamController Function()? _errorStreamFactory;

  Stream get exceptionStream => _errorStreamController!.stream;

  ActionBoxBase(this._rootFactory, this._errorStreamFactory);

  void dispose() {
    _root.dispose();
    _errorStreamController?.close();
  }

  Tuple2<ActionDescriptor<TAction, TParam, TResult>, StreamController?>
      call<TParam, TResult, TAction extends Action<TParam, TResult>>(
          ActionDescriptor<TAction, TParam, TResult> Function(TActionDirectory)
              action) {
    var descriptor = action.call(_root);
    return descriptor(_errorStreamController);
  }
}
