import 'dart:async';
import 'dart:collection';

import 'package:action_box/src/core/action.dart';
import 'package:action_box/src/core/action_descriptor.dart';
import 'package:action_box/src/utils/disposable.dart';

abstract class ActionDirectory implements Disposable {
  late Map<String, ActionDescriptor> _actionDescriptors;
  late Map<String, ActionDirectory> _actionDirectories;

  String? _alias;

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
    final directory = _actionDirectories.putIfAbsent(permanentKey, factory)
        as TActionDirectory;

    if (directory._alias?.isEmpty ?? true) {
      directory._alias = _makePath(permanentKey);
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

    final descriptor = _actionDescriptors.putIfAbsent(
            permanentKey,
            () => ActionDescriptor<TAction, TParam, TResult>(
                _makePath(permanentKey), factory))
        as ActionDescriptor<TAction, TParam, TResult>;

    return descriptor;
  }

  String _makePath(String key) =>
      (_alias?.isEmpty ?? true) ? key : '$_alias.$key';

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
