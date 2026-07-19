import 'package:uuid/uuid.dart';

/// Generates opaque string ids for [GeneratedRecord]s.
abstract class IdGenerator {
  String next();
}

/// Deterministic ids for tests: `id-1`, `id-2`, …
class SequentialIdGenerator implements IdGenerator {
  SequentialIdGenerator({this.prefix = 'id'});

  final String prefix;
  var _n = 0;

  @override
  String next() {
    _n++;
    return '$prefix-$_n';
  }
}

/// UUID v4 ids for production use.
class UuidIdGenerator implements IdGenerator {
  UuidIdGenerator([Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String next() => _uuid.v4();
}
