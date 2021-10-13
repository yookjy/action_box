class InitializationException implements Exception {
  final String _message;

  InitializationException(this._message);

  @override
  String toString() => 'InitializationException: $_message';
}