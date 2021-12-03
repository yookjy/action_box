import 'dart:async';

import 'package:action_box/src/cache/cache_provider.dart';
import 'package:action_box/src/cache/cache_storage.dart';
import 'package:action_box/src/core/action.dart';
import 'package:action_box/src/core/action_descriptor.dart';
import 'package:action_box/src/core/action_directory.dart';

abstract class ActionBoxBase<TActionDirectory extends ActionDirectory> {
  late final TActionDirectory _root = _rootFactory.call();
  late final TActionDirectory Function() _rootFactory;
  late final StreamController _errorStreamController =
      _errorStreamFactory?.call() ?? StreamController.broadcast();
  final CacheProvider _cacheProvider;
  final StreamController Function()? _errorStreamFactory;

  final Duration _defaultTimeout;


  Stream get exceptionStream => _errorStreamController.stream;

  ActionBoxBase(this._rootFactory,
      {Duration? defaultTimeout,
      StreamController Function()? errorStreamFactory,
      List<CacheStorage?>? cacheStorages})
      : _defaultTimeout = defaultTimeout ?? const Duration(seconds: 3),
        _errorStreamFactory = errorStreamFactory,
        _cacheProvider = CacheProvider(cacheStorages ?? []);

  void dispose() {
    _root.dispose();
    _errorStreamController.close();
  }

  ActionExecutor<TParam, TResult, TAction>
      call<TParam, TResult, TAction extends Action<TParam, TResult>>(
          ActionDescriptor<TAction, TParam, TResult> Function(TActionDirectory)
              action) {
    var descriptor = action(_root);
    return descriptor.call(_errorStreamController, _defaultTimeout, _cacheProvider);
  }
}
