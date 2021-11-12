import 'dart:async';

import 'package:action_box/action_box.dart';
import 'package:action_box/src/utils/tuple.dart';
// import 'package:rxdart/rxdart.dart';

import 'action_box.dart';

//import 'package:rxdart/rxdart.dart';
// You can use code generator. https://pub.dev/packages/action_box_generator
// If you use a generator, the following files are automatically created.
//  => action descriptor(directory) files : value_converter.dart, action_root.dart
//  => action_box.dart
@ActionBoxConfig(
    //actionRootType: 'ActionRoot', //optional
    generateSourceDir: ['lib', 'example']) //optional
final actionBox = ActionBox.shared(
  // You can use rx dart's operator to avoid duplication of errors.
  // errorStreamFactory: () => PublishSubject()
  // ..bufferTime(Duration(milliseconds: 500))
  //   .where((x) => x.isNotEmpty)
  //   .flatMap((x) =>
  //   (x as PublishSubject<Object>).distinct((pre, cur) => pre == cur))
  )..exceptionStream.listen((event) {
    print(event);
  });

void main() async {
  var bag = DisposeBag();

  //receive result
  actionBox((a) => a.valueConverter.getStringToListValue)
      .map()
      .listen((result) {
    result?.forEach((v) => print(v));
  }).disposedBy(bag);

  actionBox((a) => a.valueConverter.getStringToListValue)
      .map(channel: (a) => a.ch1 | a.defaultChannel)
      .listen((result) {
    result?.forEach((v) => print(v));
  }).disposedBy(bag);

  actionBox((a) => a.valueConverter.getStringToListValue)
      .map(channel: (a) => a.ch1)
      .listen((result) {
    result?.forEach((v) => print(v));
  }).disposedBy(bag);

  //request data
  actionBox((a) => a.valueConverter.getStringToListValue).go(
      channel: (c) => c.ch1,
      param: 'value',
      begin: () {/* before dispatching */},
      end: () {/* after dispatching */},
      timeout: Duration(seconds: 10),
      subscribeable: true);

  await Future.delayed(Duration(seconds: 10));
  //call dispose method when completed
  bag.dispose();
}