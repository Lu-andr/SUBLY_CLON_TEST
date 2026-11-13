import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/localization/market_localization.dart';
import '../../data/models/finance.dart';
import '../../data/models/subscription.dart';
import '../../data/providers/app_state.dart';
import '../calculator/screens/loan_calculator_screen.dart';

part 'finance_editors.dart';

String financeMenu(MarketOption market) =>
    const {
      'ru': 'Финансы',
      'kk': 'Қаржы',
      'uz': 'Moliya',
      'vi': 'Tài chính',
      'fil': 'Pananalapi',
      'es': 'Finanzas',
    }[market.locale.split('-').first] ??
    'Finances';

void openFinances(BuildContext context, AppState state, MarketOption market) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(),
        body: FinanceScreen(state: state, market: market),
      ),
    ),
  );
}

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({required this.state, required this.market, super.key});
  final AppState state;
  final MarketOption market;

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  int section = 0;
  DateTime month = DateUtils.dateOnly(DateTime.now());
  bool incomeChart = false;

  static const purple = LoanCalculatorScreen.brandPurple;
  static const fuchsia = LoanCalculatorScreen.brandFuchsia;

  bool get russian => widget.market.locale == 'ru';
  String t(String ru, String en) => russian ? ru : en;
  String get currency => widget.market.currencyCode;
  AppState get state => widget.state;
  FinanceData get data => state.finance;
  String money(int cents, [String? code]) => NumberFormat.simpleCurrency(
    locale: russian ? 'ru' : 'en',
    name: code ?? currency,
    decimalDigits: cents % 100 == 0 ? 0 : 2,
  ).format(cents / 100);
  String dateLabel(DateTime date) => DateFormat('dd.MM.yyyy').format(date);
  String monthLabel(DateTime date) => DateFormat('MM/yyyy').format(date);
  int sum(Iterable<FinanceEntry> entries) =>
      entries.fold(0, (total, entry) => total + entry.cents);
  List<FinanceEntry> entriesFor(DateTime date) =>
      monthEntries(data.entries, currency, date);

  Future<void> save(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('Не удалось сохранить изменения', 'Could not save changes'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final theme = Theme.of(context);
      return Theme(
        data: theme.copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: purple,
            brightness: theme.brightness,
            primary: theme.brightness == Brightness.dark
                ? const Color(0xFFE7B5FF)
                : purple,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  financeMenu(widget.market),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: 0,
                      label: Text(t('Подписки', 'Subscriptions')),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text(t('Обзор', 'Insights')),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text(t('Аналитика', 'Analytics')),
                    ),
                  ],
                  selected: {section},
                  onSelectionChanged: (value) =>
                      setState(() => section = value.single),
                ),
              ),
              Expanded(
                child: ListView(
                  key: PageStorageKey('finance-$section'),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: switch (section) {
                    0 => subscriptions(),
                    1 => insights(),
                    _ => analytics(),
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget panel(Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );

  Widget headline(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      title,
      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
    ),
  );

  Widget link(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback action,
  ) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: action,
    ),
  );

  List<Widget> subscriptions() {
    final today = DateUtils.dateOnly(DateTime.now());
    final end = DateTime(today.year, today.month, today.day + 8);
    final items =
        data.subscriptions.where((item) => item.currency == currency).toList()
          ..sort((a, b) => a.nextPayment.compareTo(b.nextPayment));
    final active = items.where(
      (item) => item.status == SubscriptionStatus.active,
    );
    final monthly = active.fold(
      0.0,
      (total, item) => total + item.monthlyPrice,
    );
    final soon = active
        .where(
          (item) =>
              !item.nextPayment.isBefore(today) &&
              item.nextPayment.isBefore(end),
        )
        .length;
    return [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [purple, Color(0xFF9C177E)]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white, fontSize: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('Подписки в месяц', 'Monthly subscriptions')),
                Text(
                  money((monthly * 100).round()),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t(
                    'Активных: ${active.length} · В ближайшие 7 дней: $soon',
                    'Active: ${active.length} · Due in 7 days: $soon',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      headline(t('Регулярные платежи', 'Recurring bills')),
      FilledButton.icon(
        onPressed: () => subscriptionEditor(),
        icon: const Icon(Icons.add),
        label: Text(t('Добавить подписку', 'Add subscription')),
      ),
      const SizedBox(height: 10),
      if (items.isEmpty)
        panel(Text(t('Подписок пока нет', 'No subscriptions yet'))),
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: Icon(
                item.status == SubscriptionStatus.paused
                    ? Icons.pause_circle_outline
                    : Icons.autorenew,
              ),
              title: Text(item.name),
              subtitle: Text(
                [
                  if (item.category.isNotEmpty) item.category,
                  periodLabel(item.period),
                  if (item.status == SubscriptionStatus.paused)
                    t('На паузе', 'Paused')
                  else
                    dateLabel(item.nextPayment),
                ].join(' · '),
              ),
              trailing: Text(money((item.price * 100).round(), item.currency)),
              onTap: () => subscriptionEditor(item),
            ),
          ),
        ),
    ];
  }

  String periodLabel(BillingPeriod period) => switch (period) {
    BillingPeriod.weekly => t('Еженедельно', 'Weekly'),
    BillingPeriod.quarterly => t('Ежеквартально', 'Quarterly'),
    BillingPeriod.halfYearly => t('Раз в полгода', 'Every six months'),
    BillingPeriod.yearly => t('Ежегодно', 'Yearly'),
    BillingPeriod.monthly || BillingPeriod.custom => t('Ежемесячно', 'Monthly'),
  };

  List<Widget> insights() {
    final records = entriesFor(DateTime.now());
    final expenses = records.where((entry) => entry.kind != FinanceKind.income);
    final spent = sum(expenses);
    final categoryTotals = spendingByCategory(expenses);
    final categoryLimits = limitsByCategory();
    final overspent = categoryLimits.keys
        .where(
          (category) =>
              (categoryTotals[category] ?? 0) > categoryLimits[category]!,
        )
        .length;
    final limit = data.limits[currency];
    final ratio = limit == null ? 0.0 : spent / limit;
    final near = ratio >= .8;
    final uncategorized = records
        .where((entry) => entry.category.isEmpty)
        .length;
    final unlinked = records.where((entry) => entry.account.isEmpty).length;
    final excluded = data.entries
        .where((entry) => entry.currency == currency && entry.excluded)
        .length;
    final active = data.subscriptions
        .where(
          (item) =>
              item.currency == currency &&
              item.status == SubscriptionStatus.active,
        )
        .length;
    return [
      headline(t('Состояние бюджета', 'Budget health')),
      Card(
        child: SwitchListTile(
          title: Text(t('Оповещения о бюджете', 'Budget alerts')),
          subtitle: Text(
            data.alerts && near
                ? ratio >= 1
                      ? t('Лимит достигнут', 'Budget limit reached')
                      : t(
                          'Израсходовано не менее 80% лимита',
                          'At least 80% of the budget is used',
                        )
                : t(
                    'Предупреждение на этом экране при 80% лимита',
                    'Show a warning here at 80% of the limit',
                  ),
          ),
          value: data.alerts,
          onChanged: (value) => save(
            () => state.updateFinance(
              (current) => current.copyWith(alerts: value),
            ),
          ),
        ),
      ),
      link(
        Icons.auto_awesome,
        t('Умные правила', 'Smart rules'),
        t('Категория по ключевому слову', 'Categorize by keyword'),
        rulesPage,
      ),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              limit == null
                  ? t('Месячный лимит не задан', 'No monthly limit set')
                  : '${(ratio * 100).round()}% · ${money(spent)} / ${money(limit)}',
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0).toDouble(),
              color: near ? fuchsia : purple,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            TextButton(
              onPressed: editLimit,
              child: Text(t('Месячный лимит', 'Monthly limit')),
            ),
          ],
        ),
      ),
      link(
        Icons.warning_amber,
        t('Перерасход по категориям', 'Overspent categories'),
        t(
          'Категорий сверх лимита: $overspent',
          'Categories over budget: $overspent',
        ),
        categoryBudgets,
      ),
      link(
        Icons.repeat,
        t('Регулярные подписки', 'Recurring subscriptions'),
        t('Активных: $active', 'Active: $active'),
        () => setState(() => section = 0),
      ),
      link(
        Icons.help_outline,
        t('Без категории', 'Uncategorized'),
        '$uncategorized',
        () => recordsPage(
          t('Без категории', 'Uncategorized'),
          (e) => !e.excluded && e.category.isEmpty,
        ),
      ),
      link(
        Icons.link_off,
        t('Без счёта', 'Unlinked accounts'),
        t(
          'Указать счёт вручную · $unlinked',
          'Assign an account manually · $unlinked',
        ),
        () => recordsPage(
          t('Без счёта', 'Unlinked accounts'),
          (e) => !e.excluded && e.account.isEmpty,
        ),
      ),
      link(
        Icons.visibility_off_outlined,
        t('Исключены из учёта', 'Excluded from tracking'),
        '$excluded',
        () => recordsPage(
          t('Исключены из учёта', 'Excluded from tracking'),
          (e) => e.excluded,
        ),
      ),
      FilledButton.icon(
        onPressed: () => operationEditor(),
        icon: const Icon(Icons.add),
        label: Text(t('Добавить операцию', 'Add transaction')),
      ),
    ];
  }

  List<Widget> analytics() {
    final records = entriesFor(month);
    final previous = entriesFor(DateTime(month.year, month.month - 1));
    int total(List<FinanceEntry> items, bool income) =>
        sum(items.where((item) => (item.kind == FinanceKind.income) == income));
    final income = total(records, true);
    final expenses = total(records, false);
    final selectedTotal = incomeChart ? income : expenses;
    final lastTotal = total(previous, incomeChart);
    final change = lastTotal == 0
        ? '—'
        : '${((selectedTotal - lastTotal) * 100 / lastTotal).toStringAsFixed(1)}%';
    final months = List.generate(
      6,
      (index) => DateTime(month.year, month.month - 5 + index),
    );
    final periodEntries = months.map(entriesFor).toList();
    final trend = periodEntries
        .map((items) => [total(items, incomeChart)])
        .toList();
    final comparison = periodEntries
        .map((items) => [total(items, true), total(items, false)])
        .toList();
    final today = DateUtils.dateOnly(DateTime.now());
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final end = today.year == month.year && today.month == month.month
        ? today
        : lastDay;
    final dayCount = end.day < 7 ? end.day : 7;
    final days = List.generate(dayCount, (i) => end.day - dayCount + i + 1);
    final week = days
        .map(
          (day) => [
            sum(
              records.where(
                (item) =>
                    item.kind != FinanceKind.income && item.date.day == day,
              ),
            ),
          ],
        )
        .toList();
    final categories = <String, int>{};
    for (final item in records.where(
      (e) => (e.kind == FinanceKind.income) == incomeChart,
    )) {
      final name = item.kind == FinanceKind.subscription
          ? t('Подписки', 'Subscriptions')
          : item.category.isEmpty
          ? t('Без категории', 'Uncategorized')
          : item.category;
      categories.update(
        name,
        (amount) => amount + item.cents,
        ifAbsent: () => item.cents,
      );
    }
    final breakdown = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      Row(
        children: [
          Expanded(child: headline(t('Аналитика', 'Analytics'))),
          IconButton(
            tooltip: t('Скопировать отчёт CSV', 'Copy CSV report'),
            onPressed: records.isEmpty ? null : () => copyReport(records),
            icon: const Icon(Icons.ios_share),
          ),
          IconButton(
            tooltip: t('Предыдущий месяц', 'Previous month'),
            onPressed: () =>
                setState(() => month = DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(monthLabel(month)),
          IconButton(
            tooltip: t('Следующий месяц', 'Next month'),
            onPressed: DateTime(month.year, month.month + 1).isAfter(today)
                ? null
                : () => setState(
                    () => month = DateTime(month.year, month.month + 1),
                  ),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      SegmentedButton<bool>(
        segments: [
          ButtonSegment(value: false, label: Text(t('Расходы', 'Expenses'))),
          ButtonSegment(value: true, label: Text(t('Доходы', 'Income'))),
        ],
        selected: {incomeChart},
        onSelectionChanged: (value) =>
            setState(() => incomeChart = value.single),
      ),
      const SizedBox(height: 10),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              money(selectedTotal),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            Text('$change · ${t('к прошлому месяцу', 'vs previous month')}'),
            Text(
              '${t('Чистые накопления', 'Net savings')}: ${money(income - expenses)}',
            ),
            const SizedBox(height: 14),
            bars(
              trend,
              months.map((date) => DateFormat('MM').format(date)).toList(),
              [incomeChart ? purple : fuchsia],
            ),
          ],
        ),
      ),
      headline(
        incomeChart
            ? t('Источники доходов', 'Income sources')
            : t('Расходы по категориям', 'Spending breakdown'),
      ),
      panel(
        breakdown.isEmpty
            ? Text(t('Нет операций за месяц', 'No transactions this month'))
            : Column(
                children: [
                  for (final item in breakdown)
                    ListTile(
                      dense: true,
                      title: Text(item.key),
                      trailing: Text(money(item.value)),
                      subtitle: LinearProgressIndicator(
                        value: item.value / selectedTotal,
                      ),
                    ),
                ],
              ),
      ),
      headline(
        t(
          'Расходы за последние 7 дней периода',
          'Last 7 days of spending in this period',
        ),
      ),
      panel(bars(week, days.map((day) => '$day').toList(), [fuchsia])),
      headline(t('Доходы и расходы', 'Income vs expenses')),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t(
                'Фиолетовый — доходы · Фуксия — расходы',
                'Purple — income · Fuchsia — expenses',
              ),
            ),
            const SizedBox(height: 12),
            bars(
              comparison,
              months.map((date) => DateFormat('MM').format(date)).toList(),
              [purple, fuchsia],
            ),
          ],
        ),
      ),
      link(
        Icons.receipt_long,
        t('Операции', 'Transactions'),
        t(
          'Доходы, расходы и оплаченные подписки',
          'Income, expenses and paid subscriptions',
        ),
        () => recordsPage(
          t('Операции', 'Transactions'),
          (entry) =>
              entry.date.year == month.year && entry.date.month == month.month,
        ),
      ),
      FilledButton.icon(
        onPressed: () => operationEditor(),
        icon: const Icon(Icons.add),
        label: Text(t('Добавить операцию', 'Add transaction')),
      ),
    ];
  }

  Future<void> copyReport(List<FinanceEntry> records) async {
    String quote(String text) {
      final value = RegExp(r'^\s*[=+@-]').hasMatch(text) ? "'$text" : text;
      return '"${value.replaceAll('"', '""')}"';
    }

    final csv = [
      'Date,Type,Title,Category,Amount,Currency',
      for (final entry in records)
        [
          DateFormat('yyyy-MM-dd').format(entry.date),
          entry.kind.name,
          quote(entry.title),
          quote(entry.category),
          (entry.cents / 100).toStringAsFixed(2),
          entry.currency,
        ].join(','),
    ].join('\r\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('Отчёт CSV скопирован', 'CSV report copied'))),
    );
  }

  Widget bars(List<List<int>> values, List<String> labels, List<Color> colors) {
    final max = values.expand((row) => row).fold(0, (a, b) => a > b ? a : b);
    if (max == 0) return Text(t('Нет данных', 'No data'));
    return SizedBox(
      height: 135,
      child: BarChart(
        BarChartData(
          maxY: max / 100 * 1.16,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  return index >= 0 && index < labels.length
                      ? Text(labels[index])
                      : const SizedBox.shrink();
                },
              ),
            ),
          ),
          barGroups: [
            for (final (index, row) in values.indexed)
              BarChartGroupData(
                x: index,
                barRods: [
                  for (final (series, amount) in row.indexed)
                    BarChartRodData(
                      toY: amount / 100,
                      color: colors[series],
                      width: 9,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Map<String, int> limitsByCategory() => {
    for (final item in data.limits.entries)
      if (item.key.startsWith('$currency:'))
        item.key.substring(currency.length + 1): item.value,
  };

  Map<String, int> spendingByCategory(Iterable<FinanceEntry> expenses) {
    final totals = <String, int>{};
    for (final item in expenses.where((entry) => entry.category.isNotEmpty)) {
      totals.update(
        item.category,
        (value) => value + item.cents,
        ifAbsent: () => item.cents,
      );
    }
    return totals;
  }

  void categoryBudgets() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final limits = limitsByCategory();
            final totals = spendingByCategory(
              entriesFor(DateTime.now())
                  .where((entry) => entry.kind != FinanceKind.income),
            );
            final categories = {...totals.keys, ...limits.keys}.toList()
              ..sort();
            return Scaffold(
              appBar: AppBar(
                title: Text(t('Лимиты по категориям', 'Category budgets')),
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (categories.isEmpty)
                    Text(
                      t(
                        'Укажите категорию при добавлении расхода.',
                        'Enter a category when adding an expense.',
                      ),
                    ),
                  for (final category in categories)
                    link(
                      Icons.category_outlined,
                      category,
                      '${money(totals[category] ?? 0)} / ${limits[category] == null ? "—" : money(limits[category]!)}',
                      () => editLimit(category, context),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> editLimit([String? category, BuildContext? routeContext]) async {
    final key = category == null ? currency : '$currency:$category';
    final result = await showDialog<int>(
      context: routeContext ?? context,
      builder: (_) => _FinanceEditor(
        title: category ?? t('Месячный лимит', 'Monthly limit'),
        russian: russian,
        currency: currency,
        amountOnly: true,
        cents: data.limits[key],
      ),
    );
    if (result == null || !mounted) return;
    await save(
      () => state.updateFinance((current) {
        final limits = {...current.limits};
        if (result == 0) {
          limits.remove(key);
        } else {
          limits[key] = result;
        }
        return current.copyWith(limits: limits);
      }),
    );
  }

  Future<void> subscriptionEditor([Subscription? item]) async {
    final result = await showDialog<_FinanceDraft>(
      context: context,
      builder: (_) => _FinanceEditor(
        title: item == null
            ? t('Новая подписка', 'New subscription')
            : t('Изменить подписку', 'Edit subscription'),
        russian: russian,
        currency: currency,
        subscription: item,
        isSubscription: true,
      ),
    );
    if (result == null || !mounted) return;
    switch (result.action) {
      case 'delete':
        await save(() => state.deleteSubscription(item!.id));
      case 'paid':
        await save(
          () => state.markPaid(item!.id, expectedDue: item.nextPayment),
        );
      default:
        final updated = Subscription(
          id: item?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          name: result.title,
          category: result.category,
          price: result.cents / 100,
          currency: currency,
          period: result.period,
          nextPayment: result.date,
          colorValue: item?.colorValue ?? purple.toARGB32(),
          status: result.paused
              ? SubscriptionStatus.paused
              : SubscriptionStatus.active,
          reminders: item?.reminders ?? false,
          reminderDays: item?.reminderDays ?? 3,
          note: item?.note ?? '',
          totalSpent: item?.totalSpent ?? 0,
        );
        await save(
          () => item == null
              ? state.addSubscription(updated)
              : state.updateSubscription(updated),
        );
    }
  }

  Future<void> operationEditor([
    FinanceEntry? entry,
    BuildContext? routeContext,
  ]) async {
    final result = await showDialog<_FinanceDraft>(
      context: routeContext ?? context,
      builder: (_) => _FinanceEditor(
        title: entry == null
            ? t('Новая операция', 'New transaction')
            : t('Изменить операцию', 'Edit transaction'),
        russian: russian,
        currency: currency,
        entry: entry,
      ),
    );
    if (result == null || !mounted) return;
    await save(
      () => state.updateFinance((current) {
        final items = current.entries
            .where((item) => item.id != entry?.id)
            .toList();
        if (result.action == 'delete') return current.copyWith(entries: items);
        final title = result.title;
        final matchingRule = current.rules.entries
            .where((rule) => title.toLowerCase().contains(rule.key))
            .firstOrNull;
        items.add(
          FinanceEntry(
            id: entry?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
            title: title,
            cents: result.cents,
            currency: currency,
            date: result.date,
            kind: result.kind,
            category: result.category.isEmpty
                ? matchingRule?.value ?? ''
                : result.category,
            account: result.account,
            excluded: result.excluded,
          ),
        );
        return current.copyWith(entries: items);
      }),
    );
  }

  void recordsPage(String title, bool Function(FinanceEntry) filter) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final items =
                data.entries
                    .where((e) => e.currency == currency && filter(e))
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));
            return Scaffold(
              appBar: AppBar(title: Text(title)),
              body: items.isEmpty
                  ? Center(
                      child: Text(
                        t('Операций пока нет', 'No transactions yet'),
                      ),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          title: Text(item.title),
                          subtitle: Text(
                            [
                              dateLabel(item.date),
                              if (item.category.isNotEmpty) item.category,
                              if (item.account.isNotEmpty) item.account,
                              if (item.excluded) t('Исключена', 'Excluded'),
                            ].join(' · '),
                          ),
                          trailing: Text(
                            money(
                              item.kind == FinanceKind.income
                                  ? item.cents
                                  : -item.cents,
                            ),
                          ),
                          onTap: () => operationEditor(item, context),
                        );
                      },
                    ),
            );
          },
        ),
      ),
    );
  }

  Future<void> rulesPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ListenableBuilder(
          listenable: state,
          builder: (context, _) => Scaffold(
            appBar: AppBar(title: Text(t('Умные правила', 'Smart rules'))),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  t(
                    'Если категория не заполнена, применяется первое правило, которое совпало с названием операции.',
                    'When the category is empty, the first keyword matching the transaction name is used.',
                  ),
                ),
                for (final rule in data.rules.entries)
                  ListTile(
                    title: Text(rule.key),
                    subtitle: Text(rule.value),
                    trailing: IconButton(
                      tooltip: t('Удалить правило', 'Delete rule'),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => save(
                        () => state.updateFinance(
                          (current) => current.copyWith(
                            rules: {...current.rules}..remove(rule.key),
                          ),
                        ),
                      ),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: addRule,
                  icon: const Icon(Icons.add),
                  label: Text(t('Добавить правило', 'Add rule')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> addRule() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _RuleEditor(russian: russian),
    );
    if (result == null || !mounted) return;
    await save(
      () => state.updateFinance(
        (current) => current.copyWith(
          rules: {...current.rules, result.$1.toLowerCase(): result.$2},
        ),
      ),
    );
  }
}
