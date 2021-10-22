import 'package:action_box/action_box.dart';

import 'my_action_box.dart';

// You can use code generator. https://pub.dev/packages/action_box_generator
// If you use a generator, the following files are automatically created.
//  => action descriptor(directory) files : value_converter.dart, action_root.dart
//  => my_action_box.dart
//
// @ActionBoxConfig(
//     actionBoxType: 'SpcActionBox',
//     actionRootType: 'ActionRoot',
//     generateSourceDir: ['lib', 'example'])
final actionBox = MyActionBox.instance;

void main() {
  var bag = DisposeBag();
  actionBox(action: (r) => r.valueConverter.getStringToListValue)
      .listen((result) {
    result?.forEach((v) => print(v));
  }).disposedBy(bag);

  actionBox.go(
      action: (r) => r.valueConverter.getStringToListValue,
      param: 'action box test!');

  //call dispose method when completed
  //bag.dispose();
}
