import 'dart:async';

import 'package:action_box/action_box.dart';

import 'string_to_char.dart';
import 'string_to_list.dart';

class ActionBox extends ActionBoxBase<_ActionRoot> {
  static ActionBox? _instance;
  ActionBox._(StreamController<dynamic> Function()? errorStreamFactory,
      Duration? defaultTimeout, List<CacheStorage>? cacheStorages)
      : super(() => _ActionRoot(),
            errorStreamFactory: errorStreamFactory,
            defaultTimeout: defaultTimeout,
            cacheStorages: cacheStorages);

  factory ActionBox.shared(
          {StreamController<dynamic> Function()? errorStreamFactory,
          Duration? defaultTimeout,
          List<CacheStorage>? cacheStorages}) =>
      _instance ??=
          ActionBox._(errorStreamFactory, defaultTimeout, cacheStorages);

  @override
  void dispose() {
    super.dispose();
    _instance = null;
  }
}

class _ActionRoot extends ActionDirectory {
  _ValueConverter get valueConverter =>
      putIfAbsentDirectory('valueConverter', () => _ValueConverter());

  _NestedTest1 get test1 =>
      putIfAbsentDirectory('nestedTest1', () => _NestedTest1());
}

class _NestedTest1 extends ActionDirectory {
  _NestedTest2 get test2 =>
      putIfAbsentDirectory('nestedTest2', () => _NestedTest2());
}

class _NestedTest2 extends ActionDirectory {
  _ValueConverter get valueConverter =>
      putIfAbsentDirectory('valueConverter', () => _ValueConverter());
}

class _ValueConverter extends ActionDirectory {
  ActionDescriptor<StringToList, String, List<String>?>
      get getStringToListValue =>
          putIfAbsentDescriptor('getStringToListValue', () => StringToList());

  ActionDescriptor<StringToChar, String, String> get getStringToCharValue =>
      putIfAbsentDescriptor('getStringToCharValue', () => StringToChar());
}