import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subly/data/models/finance.dart';
import 'package:subly/data/models/subscription.dart';
import 'package:subly/data/providers/app_state.dart';
import 'package:subly/data/providers/subly_repository.dart';

Subscription subscription(String id) => Subscription(
  id: id,
  name: 'Music',
  category: 'Entertainment',
  price: 99.90,
  currency: 'RUB',
  period: BillingPeriod.monthly,
  nextPayment: DateTime(2027, 1, 31),
  colorValue: 0xFF461091,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('imports saved subscriptions without seeding sample records', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SublyRepository(await SharedPreferences.getInstance());
    expect((await repository.loadFinance()).subscriptions, isEmpty);
    await repository.saveSubscriptions([
      subscription('mine'),
      subscription('spotify'),
    ]);
    final imported = await repository.loadFinance();
    expect(imported.subscriptions.map((item) => item.id), ['mine']);
  });

  test(
    'saves the payment and next billing date together exactly once',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SublyRepository(await SharedPreferences.getInstance());
      final state = AppState(repository);
      addTearDown(state.dispose);
      final item = subscription('mine');
      await state.addSubscription(item);
      await Future.wait([
        state.markPaid(
          item.id,
          expectedDue: item.nextPayment,
          paidOn: DateTime(2027, 1, 30),
        ),
        state.markPaid(
          item.id,
          expectedDue: item.nextPayment,
          paidOn: DateTime(2027, 1, 30),
        ),
        state.updateFinance((data) => data.copyWith(limits: {'RUB': 20000})),
      ]);
      final saved = await repository.loadFinance();
      expect(saved.limits, {'RUB': 20000});
      expect(saved.subscriptions.single.nextPayment, DateTime(2027, 2, 28));
      expect(saved.entries.single.cents, 9990);
      expect(saved.entries.single.kind, FinanceKind.subscription);
      expect(
        monthEntries(saved.entries, 'RUB', DateTime(2027, 1)),
        hasLength(1),
      );
      expect(monthEntries(saved.entries, 'USD', DateTime(2027, 1)), isEmpty);
      expect(monthEntries(saved.entries, 'RUB', DateTime(2027, 2)), isEmpty);
    },
  );
}
