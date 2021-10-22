import 'package:action_box/action_box.dart';

import 'action_root.dart';

class MyActionBox extends ActionBox<ActionRoot> {
  MyActionBox._internal() {
    ActionBox.setActionDirectory(ActionRoot());
  }

  static final instance = MyActionBox._internal();
}
