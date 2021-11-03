import 'dart:async';

import 'package:action_box/action_box.dart';

import 'string_to_list.dart';

class ActionBox extends ActionBoxBase<_ActionRoot> {
  static ActionBox? _instance;
  ActionBox._(StreamController<Object> Function() errorStreamFactory)
      : super(() => _ActionRoot(), errorStreamFactory);

  factory ActionBox.shared(
      StreamController<Object> Function() errorStreamFactory) {
    _instance = _instance ?? (_instance = ActionBox._(errorStreamFactory));
    return _instance!;
  }

  @override
  void dispose() {
    super.dispose();
    _instance = null;
  }
}

class _ActionRoot extends ActionDirectory {
  _ValueConverter get valueConverter =>
      putIfAbsentDirectory(() => _ValueConverter());
}

class _ValueConverter extends ActionDirectory {
  _ValueConverter() : super();

  ActionDescriptor<StringToList, String, List<String>?>
  get getStringToListValue =>
      putIfAbsentDescriptor('getStringToListValue', () => StringToList());
}
