A library for Dart developers.

## Usage

A simple usage example:

```dart
import 'package:action_box/action_box.dart';
//add generated file
import 'example.a.b.dart';

@ActionBoxConfig(
    //actionBoxType: 'ActionBox',
    //actionRootType: 'ActionRoot',
    generateSourceDir: ['*']
)
final actionBox = ActionBox.shared();

void howToUse() async {
  var bag = DisposeBag();
  //receive result
  actionBox((r) => r.valueConverter.getStringToListValue)
    .map()
    .listen((result) {
    result?.forEach((v) => print(v));
  }).disposedBy(bag);

  //request data
  actionBox((r) => r.valueConverter.getStringToListValue)
    .go(param: 'action box test!');

  await Future.delayed(Duration(seconds: 10));
  //call dispose method when completed
  bag.dispose();
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/yookjy/action_box/issues
