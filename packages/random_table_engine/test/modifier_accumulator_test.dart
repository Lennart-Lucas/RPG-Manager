import 'package:random_table_engine/generation_engine.dart';
import 'package:test/test.dart';

void main() {
  test('sums overlapping keys', () {
    final acc = ModifierAccumulator();
    acc.add({'crime': 2});
    acc.add({'crime': -1, 'visitorTraffic': 3});
    expect(acc.total('crime'), 1);
    expect(acc.total('visitorTraffic'), 3);
    expect(acc.total('unknown'), 0);
  });
}
