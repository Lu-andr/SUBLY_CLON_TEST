part of 'finance_screen.dart';

class _FinanceDraft {
  const _FinanceDraft({
    required this.date,
    this.action = 'save',
    this.title = '',
    this.cents = 0,
    this.category = '',
    this.account = '',
    this.kind = FinanceKind.expense,
    this.period = BillingPeriod.monthly,
    this.paused = false,
    this.excluded = false,
  });

  final String action, title, category, account;
  final int cents;
  final DateTime date;
  final FinanceKind kind;
  final BillingPeriod period;
  final bool paused, excluded;
}

class _FinanceEditor extends StatefulWidget {
  const _FinanceEditor({
    required this.title,
    required this.russian,
    required this.currency,
    this.entry,
    this.subscription,
    this.isSubscription = false,
    this.amountOnly = false,
    this.cents,
  });

  final String title, currency;
  final bool russian, isSubscription, amountOnly;
  final FinanceEntry? entry;
  final Subscription? subscription;
  final int? cents;

  @override
  State<_FinanceEditor> createState() => _FinanceEditorState();
}

class _FinanceEditorState extends State<_FinanceEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, amount, category, account;
  late DateTime date;
  late FinanceKind kind;
  late BillingPeriod period;
  late bool paused, excluded;

  String t(String ru, String en) => widget.russian ? ru : en;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    final sub = widget.subscription;
    final cents =
        widget.cents ??
        entry?.cents ??
        (sub == null ? null : (sub.price * 100).round());
    name = TextEditingController(text: sub?.name ?? entry?.title ?? '');
    amount = TextEditingController(
      text: cents == null ? '' : (cents / 100).toStringAsFixed(2),
    );
    category = TextEditingController(
      text: sub?.category ?? entry?.category ?? '',
    );
    account = TextEditingController(text: entry?.account ?? '');
    date = DateUtils.dateOnly(
      sub?.nextPayment ?? entry?.date ?? DateTime.now(),
    );
    kind = entry?.kind ?? FinanceKind.expense;
    period = sub?.period ?? BillingPeriod.monthly;
    paused = sub?.status == SubscriptionStatus.paused;
    excluded = entry?.excluded ?? false;
  }

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    category.dispose();
    account.dispose();
    super.dispose();
  }

  int? parseCents(String input) {
    final text = input.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(text)) return null;
    final parts = text.split('.');
    return int.parse(parts[0]) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  }

  void submit() {
    if (!form.currentState!.validate()) return;
    final cents = parseCents(amount.text)!;
    if (widget.amountOnly) {
      Navigator.pop(context, cents);
      return;
    }
    Navigator.pop(
      context,
      _FinanceDraft(
        date: date,
        title: name.text.trim(),
        cents: cents,
        category: category.text.trim(),
        account: account.text.trim(),
        kind: kind,
        period: period,
        paused: paused,
        excluded: excluded,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    scrollable: true,
    content: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.amountOnly)
            TextFormField(
              controller: name,
              maxLength: 80,
              decoration: InputDecoration(labelText: t('Название', 'Name')),
              validator: (value) => value!.trim().isEmpty
                  ? t('Введите название', 'Enter a name')
                  : null,
            ),
          TextFormField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '${t('Сумма', 'Amount')} (${widget.currency})',
            ),
            validator: (value) {
              final cents = parseCents(value ?? '');
              return cents == null || cents == 0
                  ? t('Введите сумму больше нуля', 'Enter a positive amount')
                  : null;
            },
          ),
          if (!widget.amountOnly) ...[
            const SizedBox(height: 10),
            if (widget.isSubscription)
              DropdownButtonFormField<BillingPeriod>(
                initialValue: period,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: t('Период оплаты', 'Billing period'),
                ),
                items: [
                  for (final (value, label) in [
                    (BillingPeriod.weekly, t('Еженедельно', 'Weekly')),
                    (BillingPeriod.monthly, t('Ежемесячно', 'Monthly')),
                    (BillingPeriod.quarterly, t('Ежеквартально', 'Quarterly')),
                    (
                      BillingPeriod.halfYearly,
                      t('Раз в полгода', 'Every six months'),
                    ),
                    (BillingPeriod.yearly, t('Ежегодно', 'Yearly')),
                    if (period == BillingPeriod.custom)
                      (BillingPeriod.custom, t('Другой', 'Custom')),
                  ])
                    DropdownMenuItem(value: value, child: Text(label)),
                ],
                onChanged: (value) => setState(() => period = value!),
              )
            else if (kind != FinanceKind.subscription)
              DropdownButtonFormField<FinanceKind>(
                initialValue: kind,
                isExpanded: true,
                decoration: InputDecoration(labelText: t('Тип', 'Type')),
                items: [
                  DropdownMenuItem(
                    value: FinanceKind.expense,
                    child: Text(t('Расход', 'Expense')),
                  ),
                  DropdownMenuItem(
                    value: FinanceKind.income,
                    child: Text(t('Доход', 'Income')),
                  ),
                ],
                onChanged: (value) => setState(() => kind = value!),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: category,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: t('Категория', 'Category'),
              ),
            ),
            if (!widget.isSubscription)
              TextField(
                controller: account,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: t('Счёт (вручную)', 'Account (manual)'),
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                widget.isSubscription
                    ? t('Следующее списание', 'Next payment')
                    : t('Дата', 'Date'),
              ),
              subtitle: Text(DateFormat('dd.MM.yyyy').format(date)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final today = DateUtils.dateOnly(DateTime.now());
                final chosen = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: date.isBefore(DateTime(2000))
                      ? date
                      : DateTime(2000),
                  lastDate: widget.isSubscription
                      ? DateTime(2100)
                      : (date.isAfter(today) ? date : today),
                );
                if (chosen != null && mounted) setState(() => date = chosen);
              },
            ),
            if (widget.isSubscription)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t('На паузе', 'Paused')),
                value: paused,
                onChanged: (value) => setState(() => paused = value),
              )
            else
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t('Исключить из учёта', 'Exclude from tracking')),
                value: excluded,
                onChanged: (value) => setState(() => excluded = value),
              ),
          ],
        ],
      ),
    ),
    actions: [
      if (widget.amountOnly && widget.cents != null)
        TextButton(
          onPressed: () => Navigator.pop(context, 0),
          child: Text(t('Убрать лимит', 'Remove limit')),
        ),
      if (widget.subscription != null || widget.entry != null)
        TextButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(t('Удалить запись?', 'Delete this record?')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t('Отмена', 'Cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(t('Удалить', 'Delete')),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              Navigator.pop(
                context,
                _FinanceDraft(date: date, action: 'delete'),
              );
            }
          },
          child: Text(t('Удалить', 'Delete')),
        ),
      if (widget.subscription?.status == SubscriptionStatus.active)
        TextButton(
          onPressed: () =>
              Navigator.pop(context, _FinanceDraft(date: date, action: 'paid')),
          child: Text(t('Отметить оплату', 'Mark paid')),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(t('Отмена', 'Cancel')),
      ),
      FilledButton(onPressed: submit, child: Text(t('Сохранить', 'Save'))),
    ],
  );
}

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({required this.russian});
  final bool russian;
  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  final form = GlobalKey<FormState>();
  String keyword = '', category = '';
  String t(String ru, String en) => widget.russian ? ru : en;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(t('Новое правило', 'New rule')),
    scrollable: true,
    content: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            maxLength: 40,
            decoration: InputDecoration(
              labelText: t('Ключевое слово', 'Keyword'),
            ),
            onSaved: (value) => keyword = value!.trim(),
            validator: (value) =>
                value!.trim().isEmpty ? t('Заполните поле', 'Required') : null,
          ),
          TextFormField(
            maxLength: 40,
            decoration: InputDecoration(labelText: t('Категория', 'Category')),
            onSaved: (value) => category = value!.trim(),
            validator: (value) =>
                value!.trim().isEmpty ? t('Заполните поле', 'Required') : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(t('Отмена', 'Cancel')),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          form.currentState!.save();
          Navigator.pop(context, (keyword, category));
        },
        child: Text(t('Сохранить', 'Save')),
      ),
    ],
  );
}
