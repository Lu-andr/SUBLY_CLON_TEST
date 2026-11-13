import 'subscription.dart';

enum FinanceKind { income, expense, subscription }

class FinanceEntry {
  const FinanceEntry({
    required this.id,
    required this.title,
    required this.cents,
    required this.currency,
    required this.date,
    required this.kind,
    this.category = '',
    this.account = '',
    this.excluded = false,
  });

  final String id, title, currency, category, account;
  final int cents;
  final DateTime date;
  final FinanceKind kind;
  final bool excluded;

  factory FinanceEntry.fromJson(Map<String, dynamic> json) => FinanceEntry(
    id: json['id'] as String,
    title: json['title'] as String,
    cents: json['cents'] as int,
    currency: json['currency'] as String,
    date: DateTime.parse(json['date'] as String),
    kind: FinanceKind.values.byName(json['kind'] as String),
    category: json['category'] as String,
    account: json['account'] as String,
    excluded: json['excluded'] as bool,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'cents': cents,
    'currency': currency,
    'date': date.toIso8601String(),
    'kind': kind.name,
    'category': category,
    'account': account,
    'excluded': excluded,
  };
}

class FinanceData {
  const FinanceData({
    this.subscriptions = const [],
    this.entries = const [],
    this.limits = const {},
    this.rules = const {},
    this.alerts = true,
  });

  final List<Subscription> subscriptions;
  final List<FinanceEntry> entries;
  final Map<String, int> limits;
  final Map<String, String> rules;
  final bool alerts;

  FinanceData copyWith({
    List<Subscription>? subscriptions,
    List<FinanceEntry>? entries,
    Map<String, int>? limits,
    Map<String, String>? rules,
    bool? alerts,
  }) => FinanceData(
    subscriptions: subscriptions ?? this.subscriptions,
    entries: entries ?? this.entries,
    limits: limits ?? this.limits,
    rules: rules ?? this.rules,
    alerts: alerts ?? this.alerts,
  );

  factory FinanceData.fromJson(Map<String, dynamic> json) => FinanceData(
    subscriptions: (json['subscriptions'] as List)
        .map(
          (item) =>
              Subscription.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList(),
    entries: (json['entries'] as List)
        .map(
          (item) =>
              FinanceEntry.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    limits: Map<String, int>.from(json['limits'] as Map),
    rules: Map<String, String>.from(json['rules'] as Map),
    alerts: json['alerts'] as bool,
  );

  Map<String, Object> toJson() => {
    'subscriptions': subscriptions.map((item) => item.toJson()).toList(),
    'entries': entries.map((item) => item.toJson()).toList(),
    'limits': limits,
    'rules': rules,
    'alerts': alerts,
  };
}

DateTime nextBillingDate(DateTime due, BillingPeriod period) {
  if (period == BillingPeriod.weekly) {
    return DateTime(due.year, due.month, due.day + 7);
  }
  final months = switch (period) {
    BillingPeriod.quarterly => 3,
    BillingPeriod.halfYearly => 6,
    BillingPeriod.yearly => 12,
    _ => 1,
  };
  final lastDay = DateTime(due.year, due.month + months + 1, 0).day;
  return DateTime(
    due.year,
    due.month + months,
    due.day <= lastDay ? due.day : lastDay,
  );
}

List<FinanceEntry> monthEntries(
  Iterable<FinanceEntry> entries,
  String currency,
  DateTime month,
) => entries
    .where(
      (entry) =>
          !entry.excluded &&
          entry.currency == currency &&
          entry.date.year == month.year &&
          entry.date.month == month.month,
    )
    .toList();
