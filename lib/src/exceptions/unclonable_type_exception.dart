class UnclonableTypeException implements Exception {
  final String _message;

  UnclonableTypeException(this._message);

  @override
  String toString() => 'UnclonableTypeException: $_message';
}