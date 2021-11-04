import 'dart:async';
import 'dart:collection';

import 'package:action_box/action_box.dart';
import 'package:action_box/src/actions/action.dart';
import 'package:action_box/src/actions/action_descriptor.dart';

abstract class ActionDirectory implements Disposable {
  late Map<String, ActionDescriptor> _actionDescriptors;
  late Map<String, ActionDirectory> _actionDirectories;

  ActionDirectory() {
    _actionDescriptors = HashMap();
    _actionDirectories = HashMap();
  }

  TActionDirectory
      putIfAbsentDirectory<TActionDirectory extends ActionDirectory>(
          String directoryKey, TActionDirectory Function() factory) {
    if (directoryKey.isEmpty) {
      throw ArgumentError.value(directoryKey);
    }
    final directory = _actionDirectories.putIfAbsent(
        directoryKey, () => factory()) as TActionDirectory;

    return directory;
  }

  ActionDescriptor<TAction, TParam, TResult> putIfAbsentDescriptor<
      TAction extends Action<TParam, TResult>,
      TParam,
      TResult>(String descriptorKey, TAction Function() factory) {
    if (descriptorKey.isEmpty) {
      throw ArgumentError.value(descriptorKey);
    }

    final descriptor = _actionDescriptors.putIfAbsent(descriptorKey,
            () => ActionDescriptor<TAction, TParam, TResult>(factory))
        as ActionDescriptor<TAction, TParam, TResult>;

    return descriptor;
  }

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
