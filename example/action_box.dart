import 'dart:async';

import 'package:action_box/action_box.dart';

import 'string_to_char.dart';
import 'string_to_list.dart';

class ActionBox extends ActionBoxBase<_ActionRoot> {
  static ActionBox? _instance;
  ActionBox._(StreamController<dynamic> Function()? errorStreamFactory,
      Duration? defaultTimeout)
      : super(() => _ActionRoot(),
            errorStreamFactory: errorStreamFactory,
            defaultTimeout: defaultTimeout);

  factory ActionBox.shared(
          {StreamController<dynamic> Function()? errorStreamFactory,
          Duration? defaultTimeout}) =>
      _instance ??= ActionBox._(errorStreamFactory, defaultTimeout);

  @override
  void dispose() {
    super.dispose();
    _instance = null;
  }
}

class _ActionRoot extends ActionDirectory {
  _ValueConverter get valueConverter =>
      putIfAbsentDirectory('valueConverter', () => _ValueConverter());
}

class _ValueConverter extends ActionDirectory {
  _ValueConverter() : super();

  ActionDescriptor<StringToList, String, List<String>>
      get getStringToListValue =>
          putIfAbsentDescriptor('getStringToListValue', () => StringToList());

  ActionDescriptor<StringToChar, String, String> get getStringToCharValue =>
      putIfAbsentDescriptor('getStringToCharValue', () => StringToChar());
}
