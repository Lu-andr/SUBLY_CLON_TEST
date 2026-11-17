import '../../data/models/finance.dart';
import '../../data/models/subscription.dart';

FinanceData financeExamples({
  required String currency,
  required bool russian,
  required DateTime today,
}) {
  // Illustrative amounts in local currency units, independent of real prices.
  final (netflix, chatGpt, gym, salary, interest) = switch (currency) {
    'RUB' => (699, 1990, 2500, 85000, 1200),
    'VND' => (180000, 500000, 600000, 15000000, 180000),
    'ZAR' => (160, 350, 450, 18000, 240),
    'PHP' => (450, 1150, 1800, 32000, 400),
    'UZS' => (85000, 250000, 300000, 6000000, 90000),
    'KZT' => (4500, 10000, 13000, 320000, 6500),
    'ARS' => (9500, 25000, 30000, 1000000, 16000),
    'MXN' => (220, 380, 600, 18000, 350),
    _ => (15, 20, 35, 2400, 30),
  };
  final subscriptions = [
    ('netflix', 'Netflix', russian ? 'Развлечения' : 'Entertainment', netflix),
    ('chatgpt', 'ChatGPT', russian ? 'Сервисы' : 'Services', chatGpt),
    (
      'fitness',
      russian ? 'Фитнес' : 'Fitness',
      russian ? 'Спорт' : 'Fitness',
      gym,
    ),
  ];
  final wage = russian ? 'Зарплата' : 'Salary';
  final savings = russian ? 'Проценты по вкладу' : 'Deposit interest';

  Iterable<FinanceEntry> entries() sync* {
    for (var offset = 0; offset < 6; offset++) {
      final endDay = offset == 0
          ? today.day
          : DateTime(today.year, today.month - offset + 1, 0).day;
      DateTime date(int daysAgo) => DateTime(
        today.year,
        today.month - offset,
        endDay > daysAgo ? endDay - daysAgo : 1,
      );
      final examples = [
        for (final (id, title, category, amount) in subscriptions)
          (id, title, category, amount, FinanceKind.subscription),
        ('salary', wage, wage, salary, FinanceKind.income),
        ('interest', savings, savings, interest, FinanceKind.income),
      ];
      for (final (index, item) in examples.indexed) {
        final (id, title, category, amount, kind) = item;
        yield FinanceEntry(
          id: 'demo-$offset-$id',
          title: title,
          cents: amount * 100,
          currency: currency,
          date: date(index),
          kind: kind,
          category: category,
          account: russian ? 'Демо-счёт' : 'Demo account',
        );
      }
    }
  }

  return FinanceData(
    subscriptions: [
      for (final (index, item) in subscriptions.indexed)
        Subscription(
          id: 'demo-${item.$1}',
          name: item.$2,
          category: item.$3,
          price: item.$4.toDouble(),
          currency: currency,
          period: BillingPeriod.monthly,
          nextPayment: DateTime(today.year, today.month, today.day + index + 2),
          colorValue: 0xFF461091,
          reminders: false,
        ),
    ],
    entries: entries().toList(),
    limits: {currency: (netflix + chatGpt + gym) * 125},
  );
}
