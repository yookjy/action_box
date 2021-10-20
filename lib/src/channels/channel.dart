class Channel {
  String get id => _ids[0];

  late final List<String> _ids;
  List<String> get ids => _ids;

  Channel() {
    _ids = [hashCode.toString()];
  }

  Channel._from(this._ids);

  Channel operator |(covariant Channel other) {
    return Channel._from(ids + other.ids);
  }
}
