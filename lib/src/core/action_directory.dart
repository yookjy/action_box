import 'dart:async';
import 'dart:collection';

import 'package:action_box/src/core/action.dart';
import 'package:action_box/src/core/action_descriptor.dart';
import 'package:action_box/src/utils/disposable.dart';

abstract class ActionDirectory implements Disposable {
  late Map<String, ActionDescriptor> _actionDescriptors;
  late Map<String, ActionDirectory> _actionDirectories;

  String? alias;

  ActionDirectory() {
    _actionDescriptors = HashMap();
    _actionDirectories = HashMap();
  }

  TActionDirectory
      putIfAbsentDirectory<TActionDirectory extends ActionDirectory>(
          String permanentKey, TActionDirectory Function() factory) {
    if (permanentKey.isEmpty) {
      throw ArgumentError.value(permanentKey);
    }
    final directory = _actionDirectories.putIfAbsent(
        permanentKey, () => factory()) as TActionDirectory;

    if (directory.alias?.isEmpty ?? true) {
      directory.alias = _makePath(permanentKey);
    }

    return directory;
  }

  ActionDescriptor<TAction, TParam, TResult> putIfAbsentDescriptor<
      TAction extends Action<TParam, TResult>,
      TParam,
      TResult>(String permanentKey, TAction Function() factory) {
    if (permanentKey.isEmpty) {
      throw ArgumentError.value(permanentKey);
    }

    final descriptor = _actionDescriptors.putIfAbsent(permanentKey,
            () => ActionDescriptor<TAction, TParam, TResult>(factory))
        as ActionDescriptor<TAction, TParam, TResult>;

    if (descriptor.alias?.isEmpty ?? true) {
      descriptor.alias = _makePath(permanentKey);
    }

    return descriptor;
  }

  String _makePath(String key) =>
      (alias?.isEmpty ?? true) ? key : '$alias.$key';

  @override
  FutureOr dispose() {
    _actionDescriptors.forEach((key, descriptor) {
      descriptor.dispose();
    });

    _actionDirectories.forEach((key, directory) {
      directory.dispose();
    });

    _actionDescriptors.clear();
    _actionDirectories.clear();
  }
}
