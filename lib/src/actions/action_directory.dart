import 'dart:async';
import 'dart:collection';

import 'package:action_box/src/actions/action.dart';
import 'package:action_box/src/actions/action_descriptor.dart';

abstract class ActionDirectory {
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

  FutureOr dispose() {
    _actionDescriptors.forEach((key, value) {
      value.dispose();
    });
  }
}
