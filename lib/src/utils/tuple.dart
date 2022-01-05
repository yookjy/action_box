class Tuple2<T1, T2> {
  final T1 item1;
  final T2 item2;
  const Tuple2(this.item1, this.item2);
  Tuple2.fromMap(Map<dynamic, dynamic> json)
      : item1 = json['item1'] as T1,
        item2 = json['item2'] as T2;

  @override
  String toString() => '($item1, $item2)';

  @override
  bool operator ==(covariant Tuple2<T1, T2> other) =>
      other.item1 == item1 && other.item2 == item2;

  @override
  int get hashCode => Object.hash(item1.hashCode, item2.hashCode);

  Map<String, dynamic> toJson() => {'item1': item1, 'item2': item2};
}

class Tuple3<T1, T2, T3> {
  final T1 item1;
  final T2 item2;
  final T3 item3;
  const Tuple3(this.item1, this.item2, this.item3);
  Tuple3.fromMap(Map<dynamic, dynamic> json)
      : item1 = json['item1'] as T1,
        item2 = json['item2'] as T2,
        item3 = json['item3'] as T3;

  @override
  String toString() => '($item1, $item2, $item3)';

  @override
  bool operator ==(covariant Tuple3<T1, T2, T3> other) =>
      other.item1 == item1 && other.item2 == item2 && other.item3 == item3;

  @override
  int get hashCode =>
      Object.hash(item1.hashCode, item2.hashCode, item3.hashCode);

  Map<String, dynamic> toJson() =>
      {'item1': item1, 'item2': item2, 'item3': item3};
}

class Tuple4<T1, T2, T3, T4> {
  final T1 item1;
  final T2 item2;
  final T3 item3;
  final T4 item4;
  const Tuple4(this.item1, this.item2, this.item3, this.item4);
  Tuple4.fromMap(Map<dynamic, dynamic> json)
      : item1 = json['item1'] as T1,
        item2 = json['item2'] as T2,
        item3 = json['item3'] as T3,
        item4 = json['item4'] as T4;

  @override
  String toString() => '($item1, $item2, $item3, $item4)';

  @override
  bool operator ==(covariant Tuple4<T1, T2, T3, T4> other) =>
      other.item1 == item1 &&
      other.item2 == item2 &&
      other.item3 == item3 &&
      other.item4 == item4;

  @override
  int get hashCode => Object.hash(
      item1.hashCode, item2.hashCode, item3.hashCode, item4.hashCode);

  Map<String, dynamic> toJson() =>
      {'item1': item1, 'item2': item2, 'item3': item3, 'item4': item4};
}

class Tuple5<T1, T2, T3, T4, T5> {
  final T1 item1;
  final T2 item2;
  final T3 item3;
  final T4 item4;
  final T5 item5;
  const Tuple5(this.item1, this.item2, this.item3, this.item4, this.item5);
  Tuple5.fromMap(Map<dynamic, dynamic> json)
      : item1 = json['item1'] as T1,
        item2 = json['item2'] as T2,
        item3 = json['item3'] as T3,
        item4 = json['item4'] as T4,
        item5 = json['item5'] as T5;

  @override
  String toString() => '($item1, $item2, $item3, $item4, $item5)';

  @override
  bool operator ==(covariant Tuple5<T1, T2, T3, T4, T5> other) =>
      other.item1 == item1 &&
      other.item2 == item2 &&
      other.item3 == item3 &&
      other.item4 == item4 &&
      other.item5 == item5;

  @override
  int get hashCode => Object.hash(item1.hashCode, item2.hashCode,
      item3.hashCode, item4.hashCode, item5.hashCode);

  Map<String, dynamic> toJson() => {
        'item1': item1,
        'item2': item2,
        'item3': item3,
        'item4': item4,
        'item5': item5
      };
}
