import 'dart:async';
import 'dart:collection';

import 'package:action_box/action_box.dart';
import 'package:action_box/src/actions/action.dart';
import 'package:action_box/src/actions/action_descriptor.dart';

// abstract class ActionRoot$ extends ActionDirectory {
//   late final StreamController _errorStreamController = _errorStreamFactory?.call() ?? StreamController.broadcast();
//   final StreamController Function()? _errorStreamFactory;
//
//   ActionRoot$(this._errorStreamFactory) : super();
//
//   Stream get exceptionStream => _errorStreamController.stream;
// }

abstract class ActionDirectory implements Disposable {
  late Map<String, ActionDescriptor> _actionDescriptors;
  late List<ActionDirectory> _actionDirectory;

  ActionDirectory() {
    _actionDescriptors = HashMap();
    _actionDirectory = List.empty(growable: true);
  }

  TActionDirectory
      putIfAbsentDirectory<TActionDirectory extends ActionDirectory>(
          TActionDirectory Function() factory) {
    TActionDirectory? set;
    _actionDirectory.forEach((x) {
      if (x is TActionDirectory) {
        set = x;
        return;
      }
    });

    if (set == null) {
      set = factory();
      _actionDirectory.add(set!);
    }
    return set!;
  }

  ActionDescriptor<TAction, TParam, TResult> putIfAbsentDescriptor<
      TAction extends Action<TParam, TResult>,
      TParam,
      TResult>(String actionBinderKey, TAction Function() factory) {
    if (actionBinderKey.isEmpty) {
      throw ArgumentError.value(actionBinderKey);
    }

    final actionBinder = _actionDescriptors.putIfAbsent(actionBinderKey,
            () => ActionDescriptor<TAction, TParam, TResult>(factory))
        as ActionDescriptor<TAction, TParam, TResult>;

    return actionBinder;
  }

  @override
  FutureOr dispose() {
    _actionDescriptors.forEach((key, descriptor) {
      descriptor.dispose();
    });

    _actionDirectory.forEach((directory) {
      directory.dispose();
    });

    _actionDescriptors.clear();
    _actionDirectory.clear();
  }
}
